import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/meal/application/discovery_controller.dart';
import 'package:not_eat_alone/features/meal/domain/entities/discoverable_meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/discovery_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

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

  setUp(() {
    FlavorConfig.current = FlavorConfig(flavor: Flavor.prod);
    authRepository = MockAuthRepository();
    userRepository = MockUserRepository();
    when(() => authRepository.signOut()).thenAnswer((_) async {});
    when(() => userRepository.watch('host1'))
        .thenAnswer((_) => Stream.value(_host));
  });

  Future<void> pumpDiscovery(
    WidgetTester tester, {
    required List<DiscoverableMeal> meals,
    Gender? viewerGender,
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
          discoveryControllerProvider.overrideWith(
            (ref) => Stream.value(meals),
          ),
          currentUserDocProvider.overrideWith(
            (ref) => Stream.value(_viewer(viewerGender ?? Gender.man)),
          ),
        ],
        child: MaterialApp.router(
          theme: buildTheme(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    // Two pumps to let both StreamProviders resolve past AsyncLoading.
    await tester.pump();
    await tester.pump();
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
    await pumpDiscovery(tester, meals: const []);

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
}
