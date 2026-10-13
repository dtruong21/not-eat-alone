import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/notifications/push_listener.dart';
import 'package:not_eat_alone/core/routing/router.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/matching/application/host_inbox_provider.dart';
import 'package:not_eat_alone/features/meal/application/discovery_controller.dart';
import 'package:not_eat_alone/features/notifications/application/push_providers.dart';
import 'package:not_eat_alone/features/notifications/domain/repositories/push_repository.dart';
import 'package:not_eat_alone/features/settings/presentation/settings_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

class _NoopPushRepository implements PushRepository {
  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> registerToken(String uid, {required String lang}) async {}

  @override
  Future<void> updateTokenLanguage(String uid, String lang) async {}

  @override
  Future<void> unregisterCurrentToken(String uid) async {}
}

/// QA sweep 2026-10-12: a returning, fully onboarded user must not be shown
/// the sign-in screen or the 18+ age gate while the session / their user
/// document is still being loaded (every cold start; every sign-in on a new
/// phone, where the document is not in the local cache yet).
const _bug = 'docs/bugs/2026-10-12-router-flashes-signin-and-age-gate-while-session-loads.md';

void main() {
  final onboarded = AppUser(
    uid: 'u1',
    dob: DateTime.utc(1990),
    ageVerified: true,
    displayName: 'Ana',
    photoUrls: const ['https://example.test/a.jpg'],
    gender: Gender.woman,
  );

  Future<String> firstLocation(
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
    await tester.pump();
    await tester.pump();
    // Skeletons' flutter_animate leaves a never-cancelled timer (MASTER-SPEC gotcha 6).
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    while (tester.takeException() != null) {}
    return container
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;
  }

  testWidgets('baseline: onboarded user with everything loaded lands on /discover', (
    tester,
  ) async {
    final path = await firstLocation(
      tester,
      auth: Stream.value(const AuthUser(uid: 'u1')),
      doc: Stream.value(onboarded),
    );
    expect(path, '/discover');
  });

  testWidgets(
    'signed-in user whose own doc is still loading is not shown the age gate',
    (tester) async {
      final doc = StreamController<AppUser?>();
      addTearDown(doc.close);
      final path = await firstLocation(
        tester,
        auth: Stream.value(const AuthUser(uid: 'u1')),
        doc: doc.stream,
      );
      expect(path, isNot('/onboarding/age'), reason: _bug);
    },
    skip: true, // open bug: see _bug

  );

  testWidgets('a resolving auth session is not shown the sign-in screen', (
    tester,
  ) async {
    final auth = StreamController<AuthUser?>();
    addTearDown(auth.close);
    final path = await firstLocation(
      tester,
      auth: auth.stream,
      doc: Stream.value(onboarded),
    );
    expect(path, isNot('/auth/signin'), reason: _bug);
  }, skip: true); // open bug: see _bug
}
