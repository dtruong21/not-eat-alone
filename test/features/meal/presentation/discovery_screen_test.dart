import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/widgets/empty_state.dart';
import 'package:not_eat_alone/core/design/widgets/error_state.dart';
import 'package:not_eat_alone/core/design/widgets/skeleton_card.dart';
import 'package:not_eat_alone/core/location/location_providers.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/meal/application/discovery_controller.dart';
import 'package:not_eat_alone/features/meal/domain/entities/discoverable_meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/discovery_screen.dart';
import 'package:not_eat_alone/features/notifications/application/push_providers.dart';
import 'package:not_eat_alone/features/notifications/domain/repositories/push_repository.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockPushRepository extends Mock implements PushRepository {}

const _restaurant = Restaurant(
  placeId: 'p1',
  name: 'Cafe Central',
  address: '1 Rue de Rivoli, 75001 Paris',
  lat: 48.8566,
  lng: 2.3522,
);

final _meal = Meal(
  id: 'm1',
  hostId: 'host1',
  restaurant: _restaurant,
  dateTime: DateTime(2027, 1, 5, 19, 30),
  geohash: 'u09tvw',
  womenOnly: true,
);

final _discoverableMeal = DiscoverableMeal(meal: _meal, distanceMeters: 1234);

final _host = AppUser(
  uid: 'host1',
  dob: DateTime(1990, 1, 1),
  displayName: 'Alex',
);

AppUser _viewer(Gender gender) => AppUser(
      uid: 'viewer1',
      dob: DateTime(1995, 1, 1),
      gender: gender,
    );

void main() {
  late MockAuthRepository authRepository;
  late MockUserRepository userRepository;
  var locationCalls = 0;

  setUp(() {
    FlavorConfig.current = FlavorConfig(flavor: Flavor.prod);
    locationCalls = 0;
    authRepository = MockAuthRepository();
    userRepository = MockUserRepository();
    when(() => authRepository.signOut()).thenAnswer((_) async {});
    // Read by `_onSignOut` to look up the uid for token cleanup — signed
    // out here by default so the unregister branch is skipped and most
    // tests stay focused on their own concern.
    when(() => authRepository.currentUser).thenReturn(null);
    when(() => userRepository.watch('host1'))
        .thenAnswer((_) => Stream.value(_host));
  });

  Future<void> pumpDiscovery(
    WidgetTester tester, {
    List<DiscoverableMeal> meals = const [],
    Stream<List<DiscoverableMeal>> Function()? mealsStream,
    Gender? viewerGender,
    PushRepository? pushRepository,
    Brightness brightness = Brightness.light,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DiscoveryScreen(),
        ),
        GoRoute(
          path: '/meals/detail',
          builder: (context, state) {
            final meal = state.extra! as Meal;
            return Scaffold(body: Text('detail:${meal.id}'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          userRepositoryProvider.overrideWithValue(userRepository),
          locationProvider.overrideWith((ref) async {
            locationCalls++;
            return (lat: 48.8566, lng: 2.3522);
          }),
          discoveryControllerProvider.overrideWith(
            (ref) => mealsStream != null ? mealsStream() : Stream.value(meals),
          ),
          currentUserDocProvider.overrideWith(
            (ref) => Stream.value(_viewer(viewerGender ?? Gender.man)),
          ),
          if (pushRepository != null)
            pushRepositoryProvider.overrideWithValue(pushRepository),
        ],
        child: MaterialApp.router(
          theme: buildTheme(brightness),
          routerConfig: router,
        ),
      ),
    );
    // Two pumps to let both StreamProviders resolve past AsyncLoading; the
    // second advances time so the skeleton's zero-delay shimmer start timer
    // (flutter_animate) fires and leaves nothing pending.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('shows the flavor-aware app title', (tester) async {
    await pumpDiscovery(tester, meals: [_discoverableMeal]);

    expect(find.text('Convyve'), findsOneWidget);
  });

  testWidgets('renders a card with restaurant name and distance', (
    tester,
  ) async {
    await pumpDiscovery(tester, meals: [_discoverableMeal]);

    expect(find.text(_restaurant.name), findsOneWidget);
    expect(find.text('1.2 km'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
  });

  testWidgets('an empty meal list renders the empty state', (tester) async {
    await pumpDiscovery(tester);

    expect(find.text('No meals near you yet'), findsOneWidget);
  });

  testWidgets('"Women only" badge shows for a woman viewer', (tester) async {
    await pumpDiscovery(
      tester,
      meals: [_discoverableMeal],
      viewerGender: Gender.woman,
    );

    expect(find.text('Women only'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('"Women only" badge is peach with onAccent text ($b)', (
      tester,
    ) async {
      await pumpDiscovery(
        tester,
        meals: [_discoverableMeal],
        viewerGender: Gender.woman,
        brightness: b,
      );

      final wp = buildTheme(b).extension<WarmPlayfulExtensions>()!;
      final badge = tester.widget<Container>(
        find.byKey(const Key('women_only_badge')),
      );
      expect((badge.decoration! as BoxDecoration).color, wp.peach);
      final text = tester.widget<Text>(find.text('Women only'));
      expect(text.style!.color, wp.onAccent);
      final la = wp.onAccent.computeLuminance();
      final lb = wp.peach.computeLuminance();
      final ratio = (la > lb ? la + 0.05 : lb + 0.05) /
          (la > lb ? lb + 0.05 : la + 0.05);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });
  }

  testWidgets('"Women only" badge is hidden for a man viewer', (
    tester,
  ) async {
    await pumpDiscovery(
      tester,
      meals: [_discoverableMeal],
      viewerGender: Gender.man,
    );

    expect(find.text('Women only'), findsNothing);
  });

  testWidgets('tapping a card navigates to the meal detail route', (
    tester,
  ) async {
    await pumpDiscovery(tester, meals: [_discoverableMeal]);

    await tester.tap(find.text(_restaurant.name));
    await tester.pumpAndSettle();

    expect(find.text('detail:${_meal.id}'), findsOneWidget);
  });

  testWidgets('tapping sign out calls AuthRepository.signOut', (
    tester,
  ) async {
    await pumpDiscovery(tester, meals: [_discoverableMeal]);

    await tester.tap(find.byKey(const Key('discovery_sign_out_button')));
    await tester.pump();

    verify(() => authRepository.signOut()).called(1);
  });

  testWidgets(
    'sign out unregisters the push token for the current uid before '
    'signing out',
    (tester) async {
      final pushRepository = MockPushRepository();
      when(() => pushRepository.unregisterCurrentToken(any()))
          .thenAnswer((_) async {});
      // Signed in as 'viewer1' — `_onSignOut` reads this uid off
      // `authRepository.currentUser` to unregister the right token before
      // signing out.
      when(() => authRepository.currentUser)
          .thenReturn(const AuthUser(uid: 'viewer1'));

      await pumpDiscovery(
        tester,
        meals: [_discoverableMeal],
        pushRepository: pushRepository,
      );

      await tester.tap(find.byKey(const Key('discovery_sign_out_button')));
      await tester.pump();
      await tester.pump();

      verifyInOrder([
        () => pushRepository.unregisterCurrentToken('viewer1'),
        () => authRepository.signOut(),
      ]);
    },
  );

  testWidgets('sign out fires the SignoutCompleted analytics event', (
    tester,
  ) async {
    analytics.debugSetForceSend(true);
    final calls = <String>[];
    analytics.debugSetLogSink((name, params) async {
      calls.add(name);
    });
    addTearDown(analytics.debugResetAnalytics);

    await pumpDiscovery(tester, meals: [_discoverableMeal]);

    await tester.tap(find.byKey(const Key('discovery_sign_out_button')));
    await tester.pump();

    expect(calls, contains('signout_completed'));
  });

  testWidgets(
    'sign out survives the screen unmounting while the token unregister is '
    'in flight (no ref read after the await) and still signs out',
    (tester) async {
      final gate = Completer<void>();
      final pushRepository = MockPushRepository();
      when(() => pushRepository.unregisterCurrentToken(any()))
          .thenAnswer((_) => gate.future);
      when(() => authRepository.currentUser)
          .thenReturn(const AuthUser(uid: 'viewer1'));

      await pumpDiscovery(
        tester,
        meals: [_discoverableMeal],
        pushRepository: pushRepository,
      );

      await tester.tap(find.byKey(const Key('discovery_sign_out_button')));
      await tester.pump();

      // Unmount the whole tree (disposing the screen's ref) mid-flight.
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      verify(() => authRepository.signOut()).called(1);
    },
  );

  testWidgets('loading shows a skeleton list, not a spinner', (tester) async {
    await pumpDiscovery(
      tester,
      mealsStream: () => const Stream<List<DiscoverableMeal>>.empty(),
    );

    expect(find.byType(SkeletonList), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('empty feed shows the EmptyState with the same words', (
    tester,
  ) async {
    await pumpDiscovery(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No meals near you yet'), findsOneWidget);
  });

  testWidgets('error shows ErrorState; Try again re-fetches the feed', (
    tester,
  ) async {
    var calls = 0;
    await pumpDiscovery(
      tester,
      mealsStream: () => ++calls == 1
          ? Stream<List<DiscoverableMeal>>.error(StateError('boom'))
          : Stream.value([_discoverableMeal]),
    );
    expect(find.byType(ErrorState), findsOneWidget);
    // Pull-to-refresh path: the location is read again too (not only the
    // feed provider invalidated).
    final locationBefore = locationCalls;

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(calls, 2);
    expect(locationCalls, locationBefore + 1);
    expect(find.byType(ErrorState), findsNothing);
    expect(find.text(_restaurant.name), findsOneWidget);
  });
}
