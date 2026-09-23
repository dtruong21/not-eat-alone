/// Profile edit screen — settings entry point for editing an already
/// complete profile.
///
/// Wraps the same [ProfileForm] used by onboarding's `ProfileSetupScreen`,
/// but with normal back navigation (an `AppBar` back arrow, plus whatever
/// gesture/button the platform provides — no `PopScope` override) and a
/// "Save" action that calls [ProfileController.save] (a partial update —
/// only the fields that changed here get written) and then pops back to
/// settings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/rating/presentation/widgets/rating_badge.dart';
import 'package:not_eat_alone/features/user/application/profile_controller.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/presentation/widgets/profile_form.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => ProfileEditScreenState();
}

class ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  ProfileFormData? _formData;

  void _onFormChanged(ProfileFormData data) {
    if (data != _formData) setState(() => _formData = data);
  }

  Future<void> _save() async {
    final data = _formData;
    if (data == null) return;

    final name = data.name.trim();
    final bio = data.bio?.trim();

    await ref.read(profileControllerProvider.notifier).save(
          displayName: name.isEmpty ? null : name,
          bio: (bio == null || bio.isEmpty) ? null : bio,
          gender: data.gender,
        );

    if (!mounted) return;
    final state = ref.read(profileControllerProvider);
    if (!state.hasError) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final isSubmitting = state.isLoading;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final myUid = ref.watch(currentUserDocProvider).value?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          IconButton(
            key: const Key('profile_settings_button'),
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (myUid != null) ...[
                RatingBadge(uid: myUid),
                const SizedBox(height: WarmPlayfulSpacing.s4),
              ],
              ProfileForm(onChanged: _onFormChanged),
              const SizedBox(height: WarmPlayfulSpacing.s5),
              FilledButton(
                onPressed: isSubmitting ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: WarmPlayfulSpacing.s4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
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
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
