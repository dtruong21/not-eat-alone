/// Foreground FCM banner + tap deep-linking, wired once around the shell
/// body (`app_shell.dart`). Also owns the "register the device token once a
/// signed-in uid is present" side effect.
///
/// See `docs/superpowers/specs/2026-09-22-push-notifications-design.md` §2
/// "Foreground + tap handling".
///
/// Testability: the three `FirebaseMessaging` entry points this widget
/// depends on, plus the navigation side effect, are behind small Riverpod
/// provider seams below rather than called directly — tests override them
/// via `ProviderScope`, so `PushListener` never touches the real plugin (no
/// `Firebase.initializeApp()` needed) and navigation is assertable with a
/// plain spy function, no live `GoRouter`/`Navigator` required. The core tap
/// logic is additionally exposed as the public
/// [PushListenerState.handlePayload], which takes a plain
/// `Map<String, String?>` — no `RemoteMessage` needed to unit-test the
/// mapper -> navigate -> analytics path.
library;

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/routing/router.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/notifications/application/push_registration_controller.dart';
import 'package:not_eat_alone/features/notifications/data/push_route_mapper.dart';

/// Real default: `FirebaseMessaging.onMessage` (foreground push). Override
/// in tests with a `StreamController`-backed stream.
final foregroundPushMessagesProvider = Provider<Stream<RemoteMessage>>(
  (ref) => FirebaseMessaging.onMessage,
);

/// Real default: `FirebaseMessaging.onMessageOpenedApp` (background tap).
/// Override in tests with a `StreamController`-backed stream.
final openedPushMessagesProvider = Provider<Stream<RemoteMessage>>(
  (ref) => FirebaseMessaging.onMessageOpenedApp,
);

/// Real default: `FirebaseMessaging.instance.getInitialMessage` (cold-start
/// tap). Override in tests with a fake that resolves without touching the
/// plugin/`Firebase.initializeApp()`.
final initialPushMessageProvider =
    Provider<Future<RemoteMessage?> Function()>(
  (ref) => FirebaseMessaging.instance.getInitialMessage,
);

/// The navigation side effect for a tapped push, seamed so tests can assert
/// on it with a spy instead of driving a live `GoRouter`.
final pushNavigateProvider = Provider<void Function(String location)>(
  (ref) => (location) => ref.read(routerProvider).go(location),
);

/// Wraps [child] (the shell body): shows a lightweight banner for foreground
/// pushes and navigates on a tapped push (background tap or cold start).
class PushListener extends ConsumerStatefulWidget {
  /// Creates a [PushListener] wrapping [child].
  const PushListener({required this.child, super.key});

  /// The subtree to render underneath the listener — the shell body.
  final Widget child;

  @override
  ConsumerState<PushListener> createState() => PushListenerState();
}

/// Public (not `_PushListenerState`) so widget tests can grab it via
/// `tester.state<PushListenerState>(find.byType(PushListener))` and call
/// [handlePayload] directly.
class PushListenerState extends ConsumerState<PushListener> {
  late final StreamSubscription<RemoteMessage> _foregroundSub;
  late final StreamSubscription<RemoteMessage> _openedSub;

  /// Guards `register()` so it fires once per signed-in uid, not on every
  /// rebuild of this widget.
  String? _registeredUid;

  @override
  void initState() {
    super.initState();
    _foregroundSub =
        ref.read(foregroundPushMessagesProvider).listen(_showForegroundBanner);
    _openedSub = ref.read(openedPushMessagesProvider).listen(_onTap);
    unawaited(
      ref.read(initialPushMessageProvider)().then((message) {
        if (message != null) _onTap(message);
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_foregroundSub.cancel());
    unawaited(_openedSub.cancel());
    super.dispose();
  }

  void _showForegroundBanner(RemoteMessage message) {
    final title = message.notification?.title;
    final body = message.notification?.body;
    final text = [
      if (title != null && title.isNotEmpty) title,
      if (body != null && body.isNotEmpty) body,
    ].join(' — ');
    if (text.isEmpty) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void _onTap(RemoteMessage message) => handlePayload(
        message.data.map(
          (key, dynamic value) => MapEntry(key, value?.toString()),
        ),
      );

  /// Maps a push data payload to a route (via [mapPushData]), navigates, and
  /// fires `PushOpened`. No-ops (no throw) when the payload doesn't map to a
  /// known route. Public + takes a plain map so it's directly unit-testable
  /// without a `RemoteMessage`.
  void handlePayload(Map<String, String?> data) {
    final route = mapPushData(data);
    if (route == null) return;
    ref.read(pushNavigateProvider)(route.location);
    unawaited(analytics.track(PushOpened(type: data['type'] ?? 'unknown')));
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid != null && uid != _registeredUid) {
      _registeredUid = uid;
      // Scheduled rather than called inline: this runs from build(), and
      // register() sets provider state synchronously — doing that while a
      // build is in flight would throw.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref.read(pushRegistrationControllerProvider.notifier).register(uid),
        );
      });
    }
    return widget.child;
  }
}
