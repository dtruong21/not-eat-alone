/// Phone OTP screen (`/auth/phone`).
///
/// Reached by push from `SigninScreen` after `AuthRepository.verifyPhone`'s
/// `codeSent` callback fires, carrying a [PhoneVerifyArgs] (the
/// `verificationId` plus the E.164 number). On success the
/// `authStateChanges()` stream fires, `authStateProvider` picks it up, and
/// the router's redirect advances the app (to age-gate or home) — this
/// screen never navigates on that path.
///
/// The 6th digit submits automatically; "Resend code" re-calls `verifyPhone`
/// for the same number after a 30 s cooldown and swaps in the new
/// verification id. This screen must not import `firebase_auth`: the
/// repository maps a rejected code to [InvalidSmsCodeException], which shows
/// the "code didn't work" message on the field (cleared and refocused). Any
/// other failure (and a failed resend) shows the generic sentence and keeps
/// the typed code.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/core/util/phone.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/presentation/phone_verify_args.dart';

const _codeLength = 6;
const _resendCooldown = 30;

/// How long "Resend code" waits for `codeSent` / `onError` before giving up.
const _resendTimeout = Duration(seconds: 60);
const _wrongCodeText = "That code didn't work. Check it or resend.";

/// The phone-code screen; see the library comment.
class PhoneVerifyScreen extends ConsumerStatefulWidget {
  /// Creates the screen for the code sent to `args.phoneE164`.
  const PhoneVerifyScreen({required this.args, super.key});

  /// The verification id and number from the sign-in screen.
  final PhoneVerifyArgs args;

  @override
  ConsumerState<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends ConsumerState<PhoneVerifyScreen> {
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();

  late String _verificationId = widget.args.verificationId;
  bool _isSubmitting = false;
  bool _wrongCode = false;
  bool _isResending = false;
  bool _resendFailed = false;
  bool _resentNotice = false;
  bool _verifyFailed = false;
  int _secondsLeft = _resendCooldown;
  int _resendAttempt = 0;
  Timer? _countdown;
  Timer? _resendTimer;
  late DateTime _deadline;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _resendTimer?.cancel();
    _codeFocus.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Remaining whole seconds until the cooldown deadline. Derived from the
  /// clock (not a per-tick decrement) so time spent suspended — e.g. reading
  /// the SMS in Messages — counts.
  int _remaining() {
    final ms = _deadline.difference(clock.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void _startCountdown() {
    _countdown?.cancel();
    _deadline = clock.now().add(const Duration(seconds: _resendCooldown));
    _secondsLeft = _resendCooldown;
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft = _remaining());
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    final smsCode = _codeController.text.trim();
    // The auto-submit and the keyboard action can both land here: the flag
    // (set synchronously below) keeps it to one call.
    if (smsCode.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _wrongCode = false;
      _verifyFailed = false;
      _resendFailed = false;
      _resentNotice = false;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .confirmSmsCode(verificationId: _verificationId, smsCode: smsCode);
      // Success: authStateProvider picks up the new session and the
      // router's redirect advances us — no navigation here.
    } on InvalidSmsCodeException {
      if (!mounted) return;
      _codeController.clear();
      setState(() {
        _isSubmitting = false;
        _wrongCode = true;
      });
      _codeFocus.requestFocus();
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _verifyFailed = true;
      });
    }
    // On success `_isSubmitting` stays true: the router leaves this screen,
    // and Verify must not come alive again with the used code.
  }

  Future<void> _resend() async {
    if (_isResending || _secondsLeft > 0) return;
    final attempt = ++_resendAttempt;
    setState(() {
      _isResending = true;
      _resendFailed = false;
      _resentNotice = false;
    });

    void fail() {
      if (attempt != _resendAttempt || !mounted) return;
      // Invalidate the attempt so a late codeSent/onError is ignored.
      _resendAttempt++;
      _resendTimer?.cancel();
      setState(() {
        _isResending = false;
        _resendFailed = true;
      });
    }

    _resendTimer?.cancel();
    _resendTimer = Timer(_resendTimeout, fail);
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyPhone(
            phoneE164: widget.args.phoneE164,
            codeSent: (verificationId) {
              if (attempt != _resendAttempt || !mounted) return;
              _resendTimer?.cancel();
              setState(() {
                _verificationId = verificationId;
                _isResending = false;
                _resentNotice = true;
                _wrongCode = false;
              });
              _startCountdown();
            },
            onError: (_) => fail(),
          );
    } on Object catch (_) {
      fail();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final wp = context.wp;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the code',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: WarmPlayfulType.h1Weight,
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s2),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Sent to ${formatPhoneDisplay(widget.args.phoneE164)}',
                    style: textTheme.bodyMedium?.copyWith(color: wp.muted),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                        WarmPlayfulSize.minTap,
                        WarmPlayfulSize.minTap,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text(
                      'Change',
                      semanticsLabel: 'Change phone number',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: WarmPlayfulSpacing.s5),
              TextField(
                key: const Key('phone_verify_code_field'),
                controller: _codeController,
                focusNode: _codeFocus,
                readOnly: _isSubmitting,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: _codeLength,
                textAlign: TextAlign.center,
                onChanged: (v) {
                  if (_wrongCode) setState(() => _wrongCode = false);
                  if (v.length == _codeLength) unawaited(_verify());
                },
                onSubmitted: (_) => _verify(),
                decoration: InputDecoration(
                  labelText: '6-digit code',
                  // The "0/6" counter would be re-announced on every digit.
                  counterText: '',
                  errorText: _wrongCode ? _wrongCodeText : null,
                  errorStyle: TextStyle(color: wp.dangerText),
                  errorMaxLines: 3,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
                  ),
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s4),
              AppButton(
                label: 'Verify',
                loadingLabel: 'Verifying…',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _verify,
              ),
              const SizedBox(height: WarmPlayfulSpacing.s3),
              AppButton(
                label: _secondsLeft > 0
                    ? 'Resend code in $_secondsLeft s'
                    : 'Resend code',
                loadingLabel: 'Sending code…',
                variant: AppButtonVariant.text,
                isLoading: _isResending,
                onPressed: _secondsLeft > 0 || _isResending || _isSubmitting
                    ? null
                    : _resend,
              ),
              if (_resentNotice || _resendFailed || _verifyFailed) ...[
                const SizedBox(height: WarmPlayfulSpacing.s2),
                // Appears without user action on the field: announce it.
                Semantics(
                  liveRegion: true,
                  container: true,
                  child: Text(
                    _resendFailed || _verifyFailed
                        ? 'Something went wrong — please try again.'
                        : 'Code sent again',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: _resendFailed || _verifyFailed
                          ? wp.dangerText
                          : wp.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
