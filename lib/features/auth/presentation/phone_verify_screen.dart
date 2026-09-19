/// Phone OTP screen (`/auth/phone`).
///
/// Reached from [SigninScreen] after `AuthRepository.verifyPhone`'s
/// `codeSent` callback fires, carrying the `verificationId` this screen
/// needs to complete the sign-in via `confirmSmsCode`. On success the
/// `authStateChanges()` stream fires, `authStateProvider` picks it up, and
/// the router's redirect advances the app (to age-gate or home) — this
/// screen never navigates on that path.
///
/// Errors are stored as an opaque `Object?` (mirroring `AgeGateScreen`) and
/// rendered as a single generic message: this screen must not import
/// `firebase_auth` to inspect exception types — see `AuthRepository`'s file
/// header, which names it the sole boundary for that package.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';

class PhoneVerifyScreen extends ConsumerStatefulWidget {
  const PhoneVerifyScreen({required this.verificationId, super.key});

  /// The `verificationId` handed back by `AuthRepository.verifyPhone`'s
  /// `codeSent` callback.
  final String verificationId;

  @override
  ConsumerState<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends ConsumerState<PhoneVerifyScreen> {
  final _codeController = TextEditingController();

  bool _isSubmitting = false;
  Object? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final smsCode = _codeController.text.trim();
    if (smsCode.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).confirmSmsCode(
            verificationId: widget.verificationId,
            smsCode: smsCode,
          );
      // Success: authStateProvider picks up the new session and the
      // router's redirect advances us — no navigation here.
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
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
              Text(
                'We texted you a 6-digit code.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: colors.outline),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s6),
              TextField(
                key: const Key('phone_verify_code_field'),
                controller: _codeController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: '6-digit code',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      WarmPlayfulRadius.sm,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s4),
              if (_error != null) ...[
                Text(
                  'Something went wrong — please try again.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: colors.error),
                ),
                const SizedBox(height: WarmPlayfulSpacing.s4),
              ],
              FilledButton(
                onPressed: _isSubmitting ? null : _verify,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: WarmPlayfulSpacing.s4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        height: WarmPlayfulSpacing.s4,
                        width: WarmPlayfulSpacing.s4,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : const Text('Verify'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
