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

import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/features/user/application/profile_controller.dart';
import 'package:not_eat_alone/features/user/presentation/widgets/profile_form.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => ProfileSetupScreenState();
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
    await ref
        .read(profileControllerProvider.notifier)
        .completeSetup(
          displayName: data.name.trim(),
          gender: data.gender!,
          bio: (bio == null || bio.isEmpty) ? null : bio,
        );
  }

  /// "a, b and c".
  static String _sentence(List<String> parts) => parts.length < 2
      ? parts.join()
      : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final isSubmitting = state.isLoading;
    final isValid = _formData?.isValid ?? false;
    // Before the form's first report nothing is known: show no hint.
    final missing = _formData?.missingFields ?? const <String>[];

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
                  "Name, photo and gender. That's it.",
                  style: textTheme.bodyMedium?.copyWith(
                    color: context.wp.muted,
                  ),
                ),
                const SizedBox(height: WarmPlayfulSpacing.s6),
                ProfileForm(onChanged: _onFormChanged),
                const SizedBox(height: WarmPlayfulSpacing.s5),
                AppButton(
                  label: 'Continue',
                  loadingLabel: 'Saving…',
                  isLoading: isSubmitting,
                  onPressed: (isValid && !isSubmitting) ? _continue : null,
                ),
                // Always mounted so screen readers announce text changes.
                Semantics(
                  liveRegion: true,
                  child: missing.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(
                            top: WarmPlayfulSpacing.s2,
                          ),
                          child: Text(
                            'Still needed: ${_sentence(missing)}.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: context.wp.muted,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
