/// Sign-in screen (`/auth/signin`).
///
/// Shown to signed-out users (see `authRedirect` in
/// `lib/core/routing/router.dart`). Offers three sign-in methods:
///   - Google / Apple: call straight into `AuthRepository`. On success the
///     `authStateChanges()` stream fires, `authStateProvider` picks it up,
///     and the router's redirect advances the app (to age-gate or home) —
///     this screen never navigates on that path.
///   - Phone: the user enters an E.164 number (defaulted to a French `+33`
///     prefix) and taps "Send code", which calls
///     `AuthRepository.verifyPhone`. Its `codeSent` callback carries the
///     `verificationId` this screen pushes to `/auth/phone` with, where
///     [PhoneVerifyScreen] completes the sign-in.
///
/// Only one method can be in flight at a time — [_pendingMethod] tracks
/// which, disabling all three controls and showing a spinner on the active
/// one. The phone flow holds it until `codeSent` / `onError` fires (the SMS
/// really is in flight until then), with a 60 s safety timeout. Errors are stored as an opaque `Object?` (mirroring
/// `AgeGateScreen`) and rendered as a single generic message: this screen
/// must not import `firebase_auth` to inspect exception types — see
/// `AuthRepository`'s file header, which names it the sole boundary for
/// that package.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/core/util/phone.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/onboarding/application/underage_notice_provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Route path for the phone OTP screen this screen pushes to. Kept in sync
/// with `_phoneVerifyPath` in `lib/core/routing/router.dart`.
const phoneVerifyRoutePath = '/auth/phone';

const _phoneErrorText =
    'Enter a phone number with country code, e.g. +33 6 12 34 56 78';

/// How long "Send code" waits for `codeSent` / `onError` before giving up.
const _smsTimeout = Duration(seconds: 60);

class SigninScreen extends ConsumerStatefulWidget {
  const SigninScreen({super.key});

  @override
  ConsumerState<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends ConsumerState<SigninScreen> {
  final _phoneController = TextEditingController(text: '+33');
  final _phoneFocus = FocusNode();

  SigninMethod? _pendingMethod;
  Object? _error;
  bool _phoneInvalid = false;
  Timer? _smsTimer;

  @override
  void dispose() {
    _smsTimer?.cancel();
    _phoneFocus.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _start(SigninMethod method) {
    ref.read(underageNoticeProvider.notifier).set(value: false);
    setState(() {
      _pendingMethod = method;
      _error = null;
      _phoneInvalid = false;
    });
  }

  /// Ends the phone wait (codeSent, onError, thrown, or timeout).
  void _endPhoneWait({Object? error}) {
    _smsTimer?.cancel();
    if (!mounted) return;
    setState(() {
      if (_pendingMethod == SigninMethod.phone) _pendingMethod = null;
      if (error != null) _error = error;
    });
  }

  Future<void> _signInWithGoogle() async {
    if (_pendingMethod != null) return;
    _start(SigninMethod.google);
    await analytics.track(const SigninStarted(method: SigninMethod.google));
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      // Success: authStateProvider picks up the new session and the
      // router's redirect advances us — no navigation here.
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _pendingMethod = null);
    }
  }

  Future<void> _signInWithApple() async {
    if (_pendingMethod != null) return;
    _start(SigninMethod.apple);
    await analytics.track(const SigninStarted(method: SigninMethod.apple));
    try {
      await ref.read(authRepositoryProvider).signInWithApple();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _pendingMethod = null);
    }
  }

  Future<void> _sendPhoneCode() async {
    if (_pendingMethod != null) return;
    final phoneE164 = _phoneController.text.trim();
    if (!isPlausiblePhone(phoneE164)) {
      setState(() {
        _phoneInvalid = true;
        _error = null;
      });
      // Focus scrolls the field (and its error) above the keyboard.
      _phoneFocus.requestFocus();
      return;
    }
    _start(SigninMethod.phone);
    _smsTimer = Timer(_smsTimeout, () => _endPhoneWait(error: 'timeout'));
    await analytics.track(const SigninStarted(method: SigninMethod.phone));
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyPhone(
            phoneE164: phoneE164,
            codeSent: (verificationId) {
              _endPhoneWait();
              if (!mounted) return;
              unawaited(
                context.push(phoneVerifyRoutePath, extra: verificationId),
              );
            },
            onError: (e) => _endPhoneWait(error: e),
          );
    } catch (e) {
      _endPhoneWait(error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isBusy = _pendingMethod != null;
    final showUnderage = ref.watch(underageNoticeProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showUnderage) ...[
                const _UnderageBanner(),
                const SizedBox(height: WarmPlayfulSpacing.s4),
              ] else
                const SizedBox(height: WarmPlayfulSpacing.s6),
              Text(
                'Welcome to Convyve',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: WarmPlayfulType.h1Weight,
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s2),
              Text(
                'Meet one person over a meal in Paris.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: context.wp.muted),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s6),
              AppButton(
                label: 'Continue with Google',
                loadingLabel: 'Signing in…',
                variant: AppButtonVariant.outlined,
                height: WarmPlayfulSize.actionHeight,
                icon: const Icon(Icons.g_mobiledata_rounded),
                isLoading: _pendingMethod == SigninMethod.google,
                onPressed: isBusy ? null : _signInWithGoogle,
              ),
              const SizedBox(height: WarmPlayfulSpacing.s3),
              _AppleButton(
                dark: theme.brightness == Brightness.dark,
                busy: isBusy,
                signingIn: _pendingMethod == SigninMethod.apple,
                onPressed: _signInWithApple,
              ),
              const SizedBox(height: WarmPlayfulSpacing.s5),
              Row(
                children: [
                  Expanded(child: Divider(color: colors.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: WarmPlayfulSpacing.s3,
                    ),
                    child: Text(
                      'or',
                      style: textTheme.bodyMedium?.copyWith(
                        color: context.wp.muted,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: colors.outlineVariant)),
                ],
              ),
              const SizedBox(height: WarmPlayfulSpacing.s5),
              TextField(
                key: const Key('signin_phone_field'),
                controller: _phoneController,
                focusNode: _phoneFocus,
                enabled: !isBusy,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9+ ]')),
                ],
                // Room for the error line and the button under the field.
                scrollPadding: const EdgeInsets.only(
                  bottom: WarmPlayfulSpacing.s8 + WarmPlayfulSpacing.s6,
                ),
                onChanged: (_) {
                  if (_phoneInvalid) setState(() => _phoneInvalid = false);
                },
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+33 6 12 34 56 78',
                  errorText: _phoneInvalid ? _phoneErrorText : null,
                  errorMaxLines: 3,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
                  ),
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s4),
              AppButton(
                label: 'Send code',
                loadingLabel: 'Sending code…',
                height: WarmPlayfulSize.actionHeight,
                isLoading: _pendingMethod == SigninMethod.phone,
                onPressed: isBusy ? null : _sendPhoneCode,
              ),
              if (_error != null) ...[
                const SizedBox(height: WarmPlayfulSpacing.s4),
                Text(
                  'Something went wrong — please try again.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: colors.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Official "Sign in with Apple" button (brand rules: black on light, white on
/// dark, Apple's own glyph and type). It has no loading state, so while any
/// method is in flight it is dimmed and inert, and while Apple itself is in
/// flight it is announced as "Signing in…". Text scale is capped at 1x: the
/// label is already 0.43 x height (24 px) and the height is fixed.
class _AppleButton extends StatelessWidget {
  const _AppleButton({
    required this.dark,
    required this.busy,
    required this.signingIn,
    required this.onPressed,
  });

  final bool dark;
  final bool busy;
  final bool signingIn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    Widget button = MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1,
      child: SignInWithAppleButton(
        text: 'Continue with Apple',
        height: WarmPlayfulSize.actionHeight,
        style: dark
            ? SignInWithAppleButtonStyle.white
            : SignInWithAppleButtonStyle.black,
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
        // Never null: a null handler would swap the brand colours for
        // Cupertino's disabled grey.
        onPressed: busy ? () {} : onPressed,
      ),
    );
    if (busy) {
      button = Opacity(opacity: 0.5, child: IgnorePointer(child: button));
    }
    if (signingIn) {
      button = Semantics(
        container: true,
        button: true,
        enabled: false,
        liveRegion: true,
        label: 'Signing in…',
        excludeSemantics: true,
        child: button,
      );
    }
    return button;
  }
}

/// Dismissible "you must be 18" notice shown after the age gate bounced the
/// user. Announced when it appears.
class _UnderageBanner extends ConsumerWidget {
  const _UnderageBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.wp.peach,
          borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
        ),
        child: Row(
          children: [
            const SizedBox(width: WarmPlayfulSpacing.s4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: WarmPlayfulSpacing.s3,
                ),
                child: Text(
                  'You must be 18 or older to use Convyve.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.onSurface),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              constraints: const BoxConstraints(
                minWidth: WarmPlayfulSize.minTap,
                minHeight: WarmPlayfulSize.minTap,
              ),
              icon: const Icon(Icons.close_rounded),
              onPressed: () =>
                  ref.read(underageNoticeProvider.notifier).set(value: false),
            ),
          ],
        ),
      ),
    );
  }
}
