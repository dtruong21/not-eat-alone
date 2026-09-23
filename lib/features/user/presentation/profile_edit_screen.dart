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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/safety/application/account_deletion_controller.dart';
import 'package:not_eat_alone/features/user/application/profile_controller.dart';
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

  Future<bool> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          "This permanently deletes your account and all your data. "
          "This can't be undone.",
        ),
        actions: [
          TextButton(
            key: const Key('profile_delete_account_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('profile_delete_account_confirm'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteAccount() async {
    final confirmed = await _confirmDeleteAccount(context);
    if (!confirmed) return;
    if (!mounted) return;

    await ref.read(accountDeletionControllerProvider.notifier).delete();

    if (!mounted) return;
    final error = ref.read(accountDeletionControllerProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't delete account. Try again."),
        ),
      );
    }
    // On success, signOut flips authState and the router redirect sends the
    // user to /auth/signin automatically — no navigation needed here.
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final isSubmitting = state.isLoading;
    final isDeleting = ref.watch(
      accountDeletionControllerProvider.select((s) => s.isLoading),
    );

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: WarmPlayfulSpacing.s6),
              OutlinedButton(
                key: const Key('profile_delete_account_button'),
                onPressed: isDeleting
                    ? null
                    : () => unawaited(_deleteAccount()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error),
                  padding: const EdgeInsets.symmetric(
                    vertical: WarmPlayfulSpacing.s4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
                  ),
                ),
                child: isDeleting
                    ? SizedBox(
                        height: WarmPlayfulSpacing.s4,
                        width: WarmPlayfulSpacing.s4,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.error,
                        ),
                      )
                    : const Text('Delete account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
