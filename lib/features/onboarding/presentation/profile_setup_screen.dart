/// Profile setup screen (`/onboarding/profile`).
///
/// The forced final onboarding step: shown to signed-in, age-verified users
/// who haven't completed their profile yet (name + gender + ≥1 photo).
/// Wraps [ProfileForm] and gates its own "Continue" button on the form's
/// required set being valid — [ProfileController.completeSetup] fires
/// `profile_completed` unconditionally, so THIS screen is the only thing
/// enforcing the precondition before that call happens.
///
/// No back button, no skip: `PopScope(canPop: false)` blocks the system
/// back gesture/button, and this screen never renders an `AppBar` (so there
/// is no back arrow to tap). Once `completeSetup` succeeds, the router
/// (wired separately) advances to home as `currentUserDocProvider` reflects
/// the write.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/user/application/profile_controller.dart';
import 'package:not_eat_alone/features/user/presentation/widgets/profile_form.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() =>
      ProfileSetupScreenState();
}

/// Public (not `_`-prefixed) so widget tests can reach [debugFormData] to
/// confirm the required-set gate reacts to [ProfileForm]'s reported state.
class ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  ProfileFormData? _formData;

  @visibleForTesting
  ProfileFormData? get debugFormData => _formData;

  void _onFormChanged(ProfileFormData data) {
    if (data != _formData) setState(() => _formData = data);
  }

  Future<void> _continue() async {
    final data = _formData;
    if (data == null || !data.isValid) return;

    final bio = data.bio?.trim();
    await ref.read(profileControllerProvider.notifier).completeSetup(
          displayName: data.name.trim(),
          gender: data.gender!,
          bio: (bio == null || bio.isEmpty) ? null : bio,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final isSubmitting = state.isLoading;
    final isValid = _formData?.isValid ?? false;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set up your profile',
                  style: textTheme.headlineSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: WarmPlayfulType.h1Weight,
                  ),
                ),
                const SizedBox(height: WarmPlayfulSpacing.s2),
                Text(
                  'Add a name, a photo, and tell us how you identify — this '
                  'helps us match you.',
                  style: textTheme.bodyMedium?.copyWith(color: colors.outline),
                ),
                const SizedBox(height: WarmPlayfulSpacing.s6),
                ProfileForm(onChanged: _onFormChanged),
                const SizedBox(height: WarmPlayfulSpacing.s5),
                FilledButton(
                  onPressed: (isValid && !isSubmitting) ? _continue : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: WarmPlayfulSpacing.s4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        WarmPlayfulRadius.sm,
                      ),
                    ),
                  ),
                  child: isSubmitting
                      ? SizedBox(
                          height: WarmPlayfulSpacing.s4,
                          width: WarmPlayfulSpacing.s4,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
