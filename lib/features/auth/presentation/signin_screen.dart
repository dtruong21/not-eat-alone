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
/// one. Errors are stored as an opaque `Object?` (mirroring
/// `AgeGateScreen`) and rendered as a single generic message: this screen
/// must not import `firebase_auth` to inspect exception types — see
/// `AuthRepository`'s file header, which names it the sole boundary for
/// that package.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';

/// Route path for the phone OTP screen this screen pushes to. Kept in sync
/// with `_phoneVerifyPath` in `lib/core/routing/router.dart`.
const phoneVerifyRoutePath = '/auth/phone';

class SigninScreen extends ConsumerStatefulWidget {
  const SigninScreen({super.key});

  @override
  ConsumerState<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends ConsumerState<SigninScreen> {
  final _phoneController = TextEditingController(text: '+33');

  SigninMethod? _pendingMethod;
  Object? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (_pendingMethod != null) return;
    setState(() {
      _pendingMethod = SigninMethod.google;
      _error = null;
    });
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
    setState(() {
      _pendingMethod = SigninMethod.apple;
      _error = null;
    });
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
    setState(() {
      _pendingMethod = SigninMethod.phone;
      _error = null;
    });
    await analytics.track(const SigninStarted(method: SigninMethod.phone));
    try {
      await ref.read(authRepositoryProvider).verifyPhone(
            phoneE164: phoneE164,
            codeSent: (verificationId) {
              if (!mounted) return;
              context.push(phoneVerifyRoutePath, extra: verificationId);
            },
            onError: (e) {
              if (!mounted) return;
              setState(() => _error = e);
            },
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _pendingMethod = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isBusy = _pendingMethod != null;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                'Sign in to get started.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: colors.outline),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s6),
              _AuthButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata_rounded,
                isLoading: _pendingMethod == SigninMethod.google,
                onPressed: isBusy ? null : _signInWithGoogle,
              ),
              const SizedBox(height: WarmPlayfulSpacing.s3),
              _AuthButton(
                label: 'Continue with Apple',
                icon: Icons.apple_rounded,
                isLoading: _pendingMethod == SigninMethod.apple,
                onPressed: isBusy ? null : _signInWithApple,
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
                        color: colors.outline,
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
                enabled: !isBusy,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+33 6 12 34 56 78',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      WarmPlayfulRadius.sm,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s4),
              _AuthButton(
                label: 'Send code',
                isLoading: _pendingMethod == SigninMethod.phone,
                onPressed: isBusy ? null : _sendPhoneCode,
                filled: true,
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

/// A full-width auth action button with a leading icon (optional) and an
/// inline loading spinner that replaces its label while [isLoading].
class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.icon,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
    );
    final padding = const EdgeInsets.symmetric(
      vertical: WarmPlayfulSpacing.s4,
    );

    final child = isLoading
        ? SizedBox(
            height: WarmPlayfulSpacing.s4,
            width: WarmPlayfulSpacing.s4,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: filled ? colors.onPrimary : colors.primary,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon),
                const SizedBox(width: WarmPlayfulSpacing.s2),
              ],
              Text(label),
            ],
          );

    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(padding: padding, shape: shape),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(padding: padding, shape: shape),
      child: child,
    );
  }
}
