import 'dart:async';

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
import 'package:not_eat_alone/features/meal/domain/entities/discoverable_meal.dart';
import 'package:not_eat_alone/features/user/application/profile_controller.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

class _NoopProfileController extends ProfileController {}

AppUser _user({bool? ageVerified, int? ratingCount, bool complete = false}) =>
    AppUser(
      uid: 'u1',
      dob: DateTime.utc(2000),
      ageVerified: ageVerified ?? true,
      ratingCount: ratingCount ?? 0,
      displayName: complete ? 'Alex' : null,
      photoUrls: complete ? const ['https://example.test/a.jpg'] : const [],
      gender: complete ? Gender.woman : null,
    );

void main() {
  late StreamController<AuthUser?> auth;
  late StreamController<AppUser?> userDoc;
  late ProviderContainer container;

  setUp(() {
    FlavorConfig.current = FlavorConfig(flavor: Flavor.prod);
    auth = StreamController<AuthUser?>.broadcast();
    userDoc = StreamController<AppUser?>.broadcast();
    container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => auth.stream),
        currentUserDocProvider.overrideWith((ref) => userDoc.stream),
        profileControllerProvider.overrideWith(_NoopProfileController.new),
        // Stubs so /discover (AppShell + DiscoveryScreen) builds without
        // Firebase.
        // Never emits: the screen stays on its skeleton.
        discoveryControllerProvider.overrideWith(
          (ref) => StreamController<List<DiscoverableMeal>>().stream,
        ),
        pendingRequestCountProvider.overrideWithValue(0),
        foregroundPushMessagesProvider.overrideWithValue(const Stream.empty()),
        openedPushMessagesProvider.overrideWithValue(const Stream.empty()),
        initialPushMessageProvider.overrideWithValue(() async => null),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await auth.close();
    await userDoc.close();
  });

  // Mirrors `NotEatAloneApp`: MaterialApp.router fed by `ref.watch`.
  Future<void> pumpApp(WidgetTester tester) async {
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
  }

  Future<void> emit(WidgetTester tester, {AuthUser? a, AppUser? u}) async {
    if (a != null) auth.add(a);
    if (u != null) userDoc.add(u);
    await tester.pump();
    await tester.pump();
  }

  // Lets the skeleton's shimmer timer on /discover run out before teardown.
  Future<void> drainTimers(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 5));

  String location() => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;

  testWidgets('router instance survives a user doc emit that touches no '
      'redirect input', (tester) async {
    await pumpApp(tester);
    final first = container.read(routerProvider);

    await emit(
      tester,
      a: const AuthUser(uid: 'u1'),
      u: _user(ageVerified: false),
    );
    await emit(tester, u: _user(ageVerified: false, ratingCount: 3));

    expect(identical(container.read(routerProvider), first), isTrue);
  });

  testWidgets('redirect re-runs on sign-in, ageVerified and sign-out', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(location(), '/auth/signin');

    await emit(
      tester,
      a: const AuthUser(uid: 'u1'),
      u: _user(ageVerified: false),
    );
    expect(location(), '/onboarding/age');

    // ageVerified false -> true, profile still incomplete.
    await emit(tester, u: _user());
    expect(location(), '/onboarding/profile');

    auth.add(null);
    await tester.pump();
    await tester.pump();
    expect(location(), '/auth/signin');
  });

  testWidgets('a non-redirect user doc change keeps the page and its '
      'TextField text', (tester) async {
    await pumpApp(tester);
    await emit(
      tester,
      a: const AuthUser(uid: 'u1'),
      u: _user(),
    );
    expect(location(), '/onboarding/profile');

    await tester.enterText(find.byKey(const Key('profile_name_field')), 'Alex');
    await tester.pump();

    await emit(tester, u: _user(ratingCount: 5));

    expect(location(), '/onboarding/profile');
    expect(find.text('Alex'), findsOneWidget);
  });

  testWidgets('profileComplete false -> true leaves the profile gate for '
      '/discover, and true -> false returns to it', (tester) async {
    await pumpApp(tester);
    await emit(
      tester,
      a: const AuthUser(uid: 'u1'),
      u: _user(),
    );
    expect(location(), '/onboarding/profile');

    await emit(tester, u: _user(complete: true));
    expect(location(), '/discover');

    await emit(tester, u: _user());
    expect(location(), '/onboarding/profile');
    await drainTimers(tester);
  });

  testWidgets('cold start with an already-onboarded user ends on /discover', (
    tester,
  ) async {
    await pumpApp(tester);
    await emit(
      tester,
      a: const AuthUser(uid: 'u1'),
      u: _user(complete: true),
    );
    expect(location(), '/discover');
    await drainTimers(tester);
  });
}
