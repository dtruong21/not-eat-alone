import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/matching/application/meal_request_state_provider.dart';
import 'package:not_eat_alone/features/meal/application/maps_launcher_provider.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/meal_detail_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

class MockUserRepository extends Mock implements UserRepository {}

Meal _mealAt(double lat, double lng) => Meal(
  id: 'm1',
  hostId: 'host1',
  restaurant: Restaurant(
    placeId: 'p1',
    name: 'Cafe Central',
    address: '1 Rue de Rivoli, 75001 Paris',
    lat: lat,
    lng: lng,
  ),
  dateTime: DateTime(2027, 1, 5, 19, 30),
  geohash: 'u09tvw',
);

const _buttonKey = Key('meal_detail_open_in_maps_button');

void main() {
  late MockUserRepository userRepository;

  setUp(() {
    userRepository = MockUserRepository();
    when(() => userRepository.watch('host1')).thenAnswer(
      (_) => Stream.value(AppUser(uid: 'host1', dob: DateTime(1990, 3, 15))),
    );
  });

  Future<void> pumpDetail(
    WidgetTester tester,
    Meal meal, {
    required MapsLauncher launcher,
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(userRepository),
          authStateProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(uid: 'guest1')),
          ),
          mealRequestStateProvider(
            meal.id,
          ).overrideWith((ref) => Stream.value(null)),
          mapsLauncherProvider.overrideWithValue(launcher),
        ],
        child: MaterialApp(
          theme: buildTheme(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: MealDetailScreen(meal: meal),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the action for a meal with real coordinates', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      _mealAt(48.8566, 2.3522),
      launcher: (_) async => true,
    );

    expect(find.byKey(_buttonKey), findsOneWidget);
    expect(find.text('Open in Maps'), findsOneWidget);
  });

  testWidgets('hides the action for 0,0 coordinates', (tester) async {
    await pumpDetail(tester, _mealAt(0, 0), launcher: (_) async => true);

    expect(find.byKey(_buttonKey), findsNothing);
    expect(find.text('1 Rue de Rivoli, 75001 Paris'), findsOneWidget);
  });

  testWidgets('tap hands the restaurant to the launcher', (tester) async {
    final launched = <Restaurant>[];
    await pumpDetail(
      tester,
      _mealAt(48.8566, 2.3522),
      launcher: (restaurant) async {
        launched.add(restaurant);
        return true;
      },
    );

    await tester.tap(find.byKey(_buttonKey));
    await tester.pump();

    expect(launched.single.name, 'Cafe Central');
    expect(find.text("Couldn't open Maps"), findsNothing);
  });

  testWidgets('tap fires directions_opened', (tester) async {
    await pumpDetail(
      tester,
      _mealAt(48.8566, 2.3522),
      launcher: (_) async => true,
    );

    // `analytics.track()` drops to `debugPrint` in debug builds; intercept it
    // (restored in `finally` — the framework checks before addTearDown runs).
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    try {
      await tester.tap(find.byKey(_buttonKey));
      await tester.pump();
    } finally {
      debugPrint = original;
    }

    expect(logs.where((l) => l.contains('directions_opened')), hasLength(1));
  });

  testWidgets('failed launch shows a snackbar and the button stays usable', (
    tester,
  ) async {
    var calls = 0;
    await pumpDetail(
      tester,
      _mealAt(48.8566, 2.3522),
      launcher: (_) async {
        calls++;
        return false;
      },
    );

    await tester.tap(find.byKey(_buttonKey));
    await tester.pump();

    expect(find.text("Couldn't open Maps"), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.byKey(_buttonKey));
    await tester.pump();

    expect(calls, 2);
  });

  testWidgets('a second tap while a launch is in flight is ignored', (
    tester,
  ) async {
    var calls = 0;
    await pumpDetail(
      tester,
      _mealAt(48.8566, 2.3522),
      launcher: (_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return true;
      },
    );

    await tester.tap(find.byKey(_buttonKey));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(find.byKey(_buttonKey));
    await tester.pump(const Duration(milliseconds: 300));

    expect(calls, 1);
  });

  testWidgets('exposes one labelled button to assistive tech', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpDetail(
      tester,
      _mealAt(48.8566, 2.3522),
      launcher: (_) async => true,
    );

    expect(find.bySemanticsLabel('Open Cafe Central in Maps'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Open Cafe Central in Maps')),
      matchesSemantics(
        label: 'Open Cafe Central in Maps',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('keeps a 48dp target at 2x text scale in dark mode', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      _mealAt(48.8566, 2.3522),
      launcher: (_) async => true,
      brightness: Brightness.dark,
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(_buttonKey)).height,
      greaterThanOrEqualTo(48),
    );
  });
}
