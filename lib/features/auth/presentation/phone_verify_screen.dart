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
/// verification id. This screen must not import `firebase_auth`, so it cannot
/// tell a wrong code from any other `confirmSmsCode` failure: every one of
/// them shows the "code didn't work" message on the field. Resend failures
/// show the generic sentence.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/core/util/phone.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/presentation/phone_verify_args.dart';

const _codeLength = 6;
const _resendCooldown = 30;
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
  int _secondsLeft = _resendCooldown;
  int _resendAttempt = 0;
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _codeFocus.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdown?.cancel();
    _secondsLeft = _resendCooldown;
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
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
      _resendFailed = false;
      _resentNotice = false;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .confirmSmsCode(verificationId: _verificationId, smsCode: smsCode);
      // Success: authStateProvider picks up the new session and the
      // router's redirect advances us — no navigation here.
    } on Object catch (_) {
      if (!mounted) return;
      _codeController.clear();
      setState(() => _wrongCode = true);
      _codeFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
      setState(() {
        _isResending = false;
        _resendFailed = true;
      });
    }

    try {
      await ref
          .read(authRepositoryProvider)
          .verifyPhone(
            phoneE164: widget.args.phoneE164,
            codeSent: (verificationId) {
              if (attempt != _resendAttempt || !mounted) return;
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
                    child: const Text('Change'),
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
              if (_resentNotice || _resendFailed) ...[
                const SizedBox(height: WarmPlayfulSpacing.s2),
                // Appears without user action on the field: announce it.
                Semantics(
                  liveRegion: true,
                  container: true,
                  child: Text(
                    _resendFailed
                        ? 'Something went wrong — please try again.'
                        : 'Code sent again',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: _resendFailed ? wp.dangerText : wp.muted,
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
