/// Settings screen (`/settings`) — reached from the Profile tab.
///
/// Owns the app's destructive/account actions (moved out of
/// `profile_edit_screen`, which stays focused on editing profile fields):
/// legal links, account deletion, sign-out, and the app version footer.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/config/legal_urls.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/notifications/application/push_registration_controller.dart';
import 'package:not_eat_alone/features/safety/application/account_deletion_controller.dart';

/// The app's display version + build number, e.g. "v1.1.0 (build 2)".
///
/// Behind a `FutureProvider` (rather than calling `PackageInfo.fromPlatform()`
/// directly in `build()`) so tests can override it — `PackageInfo.fromPlatform`
/// hits platform channels that aren't wired in the widget-test environment.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return 'v${info.version} (build ${info.buildNumber})';
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
            key: const Key('settings_delete_account_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('settings_delete_account_confirm'),
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

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirmDeleteAccount(context);
    if (!confirmed) return;
    if (!context.mounted) return;

    await ref.read(accountDeletionControllerProvider.notifier).delete();

    if (!context.mounted) return;
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

  /// Best-effort token cleanup before sign-out — mirrors
  /// `discovery_screen.dart`'s `_onSignOut`: a failure here must never block
  /// the user from signing out.
  Future<void> _signOut(WidgetRef ref) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid != null) {
      try {
        await ref
            .read(pushRegistrationControllerProvider.notifier)
            .unregister(uid);
      } on Exception {
        // Ignored — see doc comment above.
      }
    }
    await analytics.track(const SignoutCompleted());
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDeleting = ref.watch(
      accountDeletionControllerProvider.select((s) => s.isLoading),
    );
    final versionAsync = ref.watch(appVersionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: WarmPlayfulSpacing.s3),
          children: [
            const _SectionHeader('Legal'),
            ListTile(
              key: const Key('settings_privacy_policy'),
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              onTap: () => unawaited(_openUrl(privacyPolicyUrl)),
            ),
            ListTile(
              key: const Key('settings_terms_of_service'),
              leading: const Icon(Icons.description_outlined),
              title: const Text('Terms of Service'),
              onTap: () => unawaited(_openUrl(termsOfServiceUrl)),
            ),
            const Divider(),
            const _SectionHeader('Account'),
            ListTile(
              key: const Key('settings_sign_out'),
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign out'),
              onTap: () => unawaited(_signOut(ref)),
            ),
            ListTile(
              key: const Key('settings_delete_account'),
              leading: Icon(Icons.delete_outline_rounded, color: colors.error),
              title: Text(
                'Delete account',
                style: TextStyle(color: colors.error),
              ),
              trailing: isDeleting
                  ? SizedBox(
                      height: WarmPlayfulSpacing.s4,
                      width: WarmPlayfulSpacing.s4,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.error,
                      ),
                    )
                  : null,
              onTap: isDeleting
                  ? null
                  : () => unawaited(_deleteAccount(context, ref)),
            ),
            const Divider(),
            const _SectionHeader('About'),
            ListTile(
              key: const Key('settings_app_version'),
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Version'),
              subtitle: versionAsync.when(
                loading: () => const Text('Loading…'),
                error: (error, stackTrace) => const Text('Unavailable'),
                data: Text.new,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WarmPlayfulSpacing.s4,
        WarmPlayfulSpacing.s3,
        WarmPlayfulSpacing.s4,
        WarmPlayfulSpacing.s2,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: WarmPlayfulType.captionSize,
          height: WarmPlayfulType.captionHeight,
          fontWeight: WarmPlayfulType.captionWeight,
          color: colors.outline,
        ),
      ),
    );
  }
}
