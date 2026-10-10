import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/notifications/push_listener.dart';
import 'package:not_eat_alone/core/routing/router.dart';
import 'package:not_eat_alone/features/matching/application/host_inbox_provider.dart';
import 'package:not_eat_alone/features/notifications/application/push_providers.dart';
import 'package:not_eat_alone/features/notifications/domain/repositories/push_repository.dart';
import 'package:not_eat_alone/features/meal/application/discovery_controller.dart';
import 'package:not_eat_alone/features/settings/presentation/settings_screen.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

/// Push registration runs for any signed-in, onboarded user; keep it off
/// Firebase in these router tests.
class _NoopPushRepository implements PushRepository {
  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> registerToken(String uid) async {}

  @override
  Future<void> unregisterCurrentToken(String uid) async {}
}

/// QA sweep 2026-10-09: the router must survive a change to the signed-in
/// user's own doc (e.g. `ratingAvg` rewritten by the `onRatingCreated`
/// function while the user is mid-chat) without being rebuilt, because a new
/// `GoRouter` resets navigation to `initialLocation`.
void main() {
  final base = AppUser(
    uid: 'u1',
    dob: DateTime.utc(1990),
    ageVerified: true,
    displayName: 'Ana',
    photoUrls: const ['https://example.test/a.jpg'],
    gender: Gender.woman,
  );

  Future<ProviderContainer> boot(StreamController<AppUser?> docs) async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(uid: 'u1')),
        ),
        currentUserDocProvider.overrideWith((ref) => docs.stream),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(docs.close);
    container.listen(routerProvider, (_, __) {});
    container.listen(currentUserDocProvider, (_, __) {});
    docs.add(base);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test(
    'router instance is stable when the user doc is re-emitted unchanged',
    () async {
      final docs = StreamController<AppUser?>();
      final container = await boot(docs);
      final before = container.read(routerProvider);
      docs.add(base.copyWith());
      await Future<void>.delayed(Duration.zero);
      expect(identical(container.read(routerProvider), before), isTrue);
    },
  );

  _frameworkBehaviour();

  // The fix must not lose the gating: the redirect still re-runs when a gate
  // input (signed in / age verified / profile complete) changes. Mounted via
  // `MaterialApp.router` so the router actually parses locations; screens that
  // need Firebase may throw while building, which is irrelevant here (only the
  // resolved location is asserted), so those errors are drained.
  group('redirect still follows gate changes', () {
    Future<ProviderContainer> mount(
      WidgetTester tester, {
      required Stream<AuthUser?> auth,
      required Stream<AppUser?> doc,
    }) async {
      FlavorConfig.current = FlavorConfig(flavor: Flavor.stage);
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => auth),
          currentUserDocProvider.overrideWith((ref) => doc),
          discoveryControllerProvider.overrideWith((ref) => Stream.value([])),
          pendingRequestCountProvider.overrideWithValue(0),
          appVersionProvider.overrideWith((ref) async => '1.0.0'),
          foregroundPushMessagesProvider.overrideWithValue(
            const Stream<RemoteMessage>.empty(),
          ),
          openedPushMessagesProvider.overrideWithValue(
            const Stream<RemoteMessage>.empty(),
          ),
          initialPushMessageProvider.overrideWithValue(() async => null),
          pushRepositoryProvider.overrideWithValue(_NoopPushRepository()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp.router(
              theme: buildTheme(Brightness.light),
              routerConfig: ref.watch(routerProvider),
            ),
          ),
        ),
      );
      return container;
    }

    String location(ProviderContainer c) => c
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
      // Drain build errors from Firebase-backed screens we don't stub.
      while (tester.takeException() != null) {}
    }

    testWidgets('incomplete profile -> setup, then home once complete', (
      tester,
    ) async {
      final docs = StreamController<AppUser?>();
      addTearDown(docs.close);
      final container = await mount(
        tester,
        auth: Stream.value(const AuthUser(uid: 'u1')),
        doc: docs.stream,
      );

      docs.add(base.copyWith(photoUrls: const []));
      await settle(tester);
      expect(location(container), '/onboarding/profile');

      docs.add(base);
      await settle(tester);
      expect(location(container), '/discover');
    });

    testWidgets('signing out sends the user to sign-in', (tester) async {
      final auth = StreamController<AuthUser?>();
      addTearDown(auth.close);
      final container = await mount(
        tester,
        auth: auth.stream,
        doc: Stream.value(base),
      );

      auth.add(const AuthUser(uid: 'u1'));
      await settle(tester);
      expect(location(container), '/discover');

      auth.add(null);
      await settle(tester);
      expect(location(container), '/auth/signin');
    });
  });

  // End-to-end through the real `routerProvider` + `MaterialApp.router`: the
  // user opens Settings, then their own user doc changes (here: the rating
  // aggregate written by the `onRatingCreated` function). They must stay put.
  testWidgets('a user-doc change does not navigate away from /settings', (
    tester,
  ) async {
    FlavorConfig.current = FlavorConfig(flavor: Flavor.stage);
    final docs = StreamController<AppUser?>();
    addTearDown(docs.close);
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(uid: 'u1')),
        ),
        currentUserDocProvider.overrideWith((ref) => docs.stream),
        discoveryControllerProvider.overrideWith((ref) => Stream.value([])),
        pendingRequestCountProvider.overrideWithValue(0),
        appVersionProvider.overrideWith((ref) async => '1.0.0'),
        foregroundPushMessagesProvider.overrideWithValue(
          const Stream<RemoteMessage>.empty(),
        ),
        openedPushMessagesProvider.overrideWithValue(
          const Stream<RemoteMessage>.empty(),
        ),
        initialPushMessageProvider.overrideWithValue(() async => null),
        pushRepositoryProvider.overrideWithValue(_NoopPushRepository()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            theme: buildTheme(Brightness.light),
            routerConfig: ref.watch(routerProvider),
          ),
        ),
      ),
    );
    docs.add(base);
    await tester.pump();
    await tester.pump();
    expect(find.text('Chats'), findsOneWidget); // the shell (Discover tab)

    container.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsNothing);
    expect(find.text('Contact support'), findsOneWidget);

    docs.add(base.copyWith(ratingAvg: 4.5, ratingCount: 1));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsNothing, reason: 'sent back to /discover');
    expect(find.text('Contact support'), findsOneWidget);
  });

  test(
    'router instance is stable when only ratingAvg/ratingCount change',
    () async {
      final docs = StreamController<AppUser?>();
      final container = await boot(docs);
      final before = container.read(routerProvider);
      docs.add(base.copyWith(ratingAvg: 4.5, ratingCount: 1));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        identical(container.read(routerProvider), before),
        isTrue,
        reason: 'a new GoRouter resets the whole navigation stack to /discover',
      );
    },
  );
}

/// Framework-behaviour check for the same wiring `routerProvider` uses
/// (`Provider<GoRouter>` that watches a value, mounted via
/// `MaterialApp.router`): what actually happens to the visible screen when the
/// watched value changes and a new GoRouter is built.
void _frameworkBehaviour() {
  testWidgets('a rebuilt GoRouter sends the user back to initialLocation', (
    tester,
  ) async {
    final tick = StateProvider<int>((ref) => 0);
    final routerP = Provider<GoRouter>((ref) {
      ref.watch(tick);
      return GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Text('home')),
          GoRoute(path: '/chat', builder: (_, __) => const Text('chat')),
        ],
      );
    });
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return MaterialApp.router(routerConfig: ref.watch(routerP));
          },
        ),
      ),
    );
    captured.read(routerP).go('/chat');
    await tester.pumpAndSettle();
    expect(find.text('chat'), findsOneWidget);
    captured.read(tick.notifier).state++;
    await tester.pumpAndSettle();
    // Characterisation: this is why the router must NOT be rebuilt on
    // unrelated state changes (see the router stability tests above).
    expect(find.text('home'), findsOneWidget);
    expect(find.text('chat'), findsNothing);
  });
}
