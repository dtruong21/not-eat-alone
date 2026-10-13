/// Settings screen (`/settings`) — reached from the Profile tab.
///
/// Grouped Account / Safety / Notifications (iOS) / Legal / About, with the
/// destructive Delete account last. Owns the account actions (moved out of
/// `profile_edit_screen`, which stays focused on editing profile fields).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/config/legal_urls.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/util/phone.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/notifications/application/push_providers.dart';
import 'package:not_eat_alone/features/notifications/domain/repositories/push_repository.dart';
import 'package:not_eat_alone/features/safety/application/account_deletion_controller.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

/// The app's display version + build number, e.g. "v1.1.0 (build 2)".
///
/// Behind a `FutureProvider` (rather than calling `PackageInfo.fromPlatform()`
/// directly in `build()`) so tests can override it — `PackageInfo.fromPlatform`
/// hits platform channels that aren't wired in the widget-test environment.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return 'v${info.version} (build ${info.buildNumber})';
});

/// Opens this app's page in the iOS Settings app (where notifications are
/// switched on or off). A provider so tests can replace the launch.
final openAppSettingsProvider = Provider<Future<bool> Function()>(
  (ref) =>
      () => launchUrl(Uri.parse('app-settings:')),
);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Opens the mail app addressed to support. The address is also the tile
  /// subtitle, so a user with no mail app can still read and copy it.
  Future<void> _contactSupport(BuildContext context) async {
    final uri = Uri.parse('mailto:$supportEmail?subject=Convyve%20support');
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } on Object {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settingsMailFailed(supportEmail))),
      );
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    // Read before the await: `ref` must not be used once the screen may have
    // unmounted, and a confirmed sign-out still completes in that case.
    final auth = ref.read(authRepositoryProvider);
    // The plain repository, not `pushRegistrationControllerProvider.notifier`:
    // that controller is autoDispose with no listener, so it is gone by the
    // time the dialog is confirmed and `unregister` would throw (swallowed
    // below), leaving the FCM token registered to the signed-out account.
    final push = ref.read(pushRepositoryProvider);
    final uid = auth.currentUser?.uid;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.settingsSignOutTitle),
        actions: [
          TextButton(
            key: const Key('settings_sign_out_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('settings_sign_out_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.settingsSignOut),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await _signOut(auth, push, uid);
  }

  Future<bool> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.settingsDeleteTitle),
        content: Text(dialogContext.l10n.settingsDeleteBody),
        actions: [
          TextButton(
            key: const Key('settings_delete_account_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          TextButton(
            key: const Key('settings_delete_account_confirm'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.settingsDeleteAccount),
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
        SnackBar(content: Text(context.l10n.settingsDeleteFailed)),
      );
    }
    // On success, signOut flips authState and the router redirect sends the
    // user to /auth/signin automatically — no navigation needed here.
  }

  /// Best-effort token cleanup before sign-out: a failure here must never
  /// block the user from signing out.
  Future<void> _signOut(
    AuthRepository auth,
    PushRepository push,
    String? uid,
  ) async {
    if (uid != null) {
      try {
        await push.unregisterCurrentToken(uid);
      } on Exception {
        // Ignored — see doc comment above.
      }
    }
    await analytics.track(const SignoutCompleted());
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isDeleting = ref.watch(
      accountDeletionControllerProvider.select((s) => s.isLoading),
    );
    final versionAsync = ref.watch(appVersionProvider);
    final phone = ref.watch(
      authStateProvider.select((a) => a.value?.phoneNumber),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: WarmPlayfulSpacing.s3),
          children: [
            _SectionHeader(l10n.settingsSectionAccount),
            ListTile(
              key: const Key('settings_edit_profile'),
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(l10n.settingsEditProfile),
              trailing: const Icon(Icons.chevron_right_rounded),
              // `/profile` is a shell tab: go, not push.
              onTap: () => context.go('/profile'),
            ),
            if (phone != null)
              ListTile(
                key: const Key('settings_phone_number'),
                leading: const Icon(Icons.phone_outlined),
                title: Text(l10n.settingsPhoneNumber),
                subtitle: Text(formatPhoneDisplay(phone)),
              ),
            ListTile(
              key: const Key('settings_sign_out'),
              leading: const Icon(Icons.logout_rounded),
              title: Text(l10n.settingsSignOut),
              onTap: () => unawaited(_confirmSignOut(context, ref)),
            ),
            const Divider(),
            _SectionHeader(l10n.settingsSectionSafety),
            ListTile(
              key: const Key('settings_blocked_people'),
              leading: const Icon(Icons.block_rounded),
              title: Text(l10n.blockedTitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => unawaited(context.push('/settings/blocked')),
            ),
            ListTile(
              key: const Key('settings_safety_tips'),
              leading: const Icon(Icons.health_and_safety_outlined),
              title: Text(l10n.safetyTipsTitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => unawaited(context.push('/settings/safety')),
            ),
            ListTile(
              key: const Key('settings_contact_support'),
              leading: const Icon(Icons.mail_outline_rounded),
              title: Text(l10n.settingsContactSupport),
              subtitle: const Text(supportEmail),
              onTap: () => unawaited(_contactSupport(context)),
            ),
            const Divider(),
            // ponytail: iOS only; Android has no equivalent `app-settings:`
            // URL without a new package, add the Android row with it.
            if (defaultTargetPlatform == TargetPlatform.iOS) ...[
              _SectionHeader(l10n.settingsSectionNotifications),
              ListTile(
                key: const Key('settings_notifications'),
                leading: const Icon(Icons.notifications_none_rounded),
                title: Text(l10n.settingsNotificationSettings),
                subtitle: Text(l10n.settingsNotificationSubtitle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => unawaited(ref.read(openAppSettingsProvider)()),
              ),
              const Divider(),
            ],
            _SectionHeader(l10n.settingsSectionLegal),
            ListTile(
              key: const Key('settings_privacy_policy'),
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.settingsPrivacyPolicy),
              onTap: () => unawaited(_openUrl(privacyPolicyUrl)),
            ),
            ListTile(
              key: const Key('settings_terms_of_service'),
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.settingsTermsOfService),
              onTap: () => unawaited(_openUrl(termsOfServiceUrl)),
            ),
            ListTile(
              key: const Key('settings_licenses'),
              leading: const Icon(Icons.article_outlined),
              title: Text(l10n.settingsLicenses),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showLicensePage(
                context: context,
                applicationName: FlavorConfig.current.appTitle,
                applicationVersion: versionAsync.value,
              ),
            ),
            const Divider(),
            _SectionHeader(l10n.settingsSectionAbout),
            ListTile(
              key: const Key('settings_app_version'),
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(l10n.settingsVersion),
              subtitle: versionAsync.when(
                loading: () => Text(l10n.settingsVersionLoading),
                error: (error, stackTrace) =>
                    Text(l10n.settingsVersionUnavailable),
                data: Text.new,
              ),
            ),
            const Divider(),
            // Last and apart: the one destructive action.
            ListTile(
              key: const Key('settings_delete_account'),
              leading: Icon(
                Icons.delete_outline_rounded,
                color: context.wp.dangerText,
              ),
              title: Text(
                l10n.settingsDeleteAccount,
                style: TextStyle(color: context.wp.dangerText),
              ),
              trailing: isDeleting
                  ? SizedBox(
                      height: WarmPlayfulSpacing.s4,
                      width: WarmPlayfulSpacing.s4,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.wp.dangerText,
                      ),
                    )
                  : null,
              onTap: isDeleting
                  ? null
                  : () => unawaited(_deleteAccount(context, ref)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WarmPlayfulSpacing.s4,
        WarmPlayfulSpacing.s3,
        WarmPlayfulSpacing.s4,
        WarmPlayfulSpacing.s2,
      ),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: TextStyle(
            fontSize: WarmPlayfulType.captionSize,
            height: WarmPlayfulType.captionHeight,
            fontWeight: WarmPlayfulType.captionWeight,
            color: context.wp.muted,
          ),
        ),
      ),
    );
  }
}
