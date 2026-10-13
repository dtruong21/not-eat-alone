import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/matching/application/meal_request_state_provider.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/meal/application/meal_providers.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal_status.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/domain/repositories/meal_repository.dart';
import 'package:not_eat_alone/features/meal/presentation/meal_detail_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations.dart';

import '../../../helpers/load_app_fonts.dart';

class _MockUserRepository extends Mock implements UserRepository {}

/// Hands the screen a stream the test drives.
class _FakeMeals extends Fake implements MealRepository {
  final controller = StreamController<Meal?>();
  String? watchedId;

  @override
  Stream<Meal?> watchMeal(String id) {
    watchedId = id;
    return controller.stream;
  }
}

const _restaurant = Restaurant(
  placeId: 'p1',
  name: 'Cafe Central',
  address: '1 Rue de Rivoli, 75001 Paris',
  lat: 48.8566,
  lng: 2.3522,
);

final _open = Meal(
  id: 'm1',
  hostId: 'host1',
  restaurant: _restaurant,
  dateTime: DateTime(2027, 1, 5, 19, 30),
  geohash: 'u09tvw',
);

void main() {
  setUpAll(loadAppFonts);

  late _FakeMeals meals;
  late _MockUserRepository users;

  setUp(() {
    meals = _FakeMeals();
    users = _MockUserRepository();
    when(() => users.watch('host1')).thenAnswer(
      (_) => Stream.value(AppUser(uid: 'host1', dob: DateTime(1990, 3, 15))),
    );
  });
  tearDown(() => meals.controller.close());

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    Size? size,
    double textScale = 1,
    String viewer = 'guest1',
  }) async {
    if (size != null) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(meals),
          userRepositoryProvider.overrideWithValue(users),
          authStateProvider.overrideWith(
            (ref) => Stream.value(AuthUser(uid: viewer)),
          ),
          currentUserDocProvider.overrideWith(
            (ref) => Stream.value(AppUser(uid: viewer, dob: DateTime(1995, 6))),
          ),
          mealRequestStateProvider(
            'm1',
          ).overrideWith((ref) => Stream<JoinRequest?>.value(null)),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: MealDetailScreen(meal: _open),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> emit(WidgetTester tester, Meal? meal) async {
    meals.controller.add(meal);
    await tester.pump();
    await tester.pump();
  }

  final join = find.byKey(const Key('meal_detail_request_to_join_button'));

  testWidgets('renders the passed meal before the first snapshot', (
    tester,
  ) async {
    await pump(tester);

    expect(meals.watchedId, 'm1');
    expect(find.text('Cafe Central'), findsOneWidget);
    expect(join, findsOneWidget);
  });

  for (final c in [
    (
      locale: const Locale('en'),
      cancelled: 'Meal cancelled',
      ended: 'Meal ended',
    ),
    (
      locale: const Locale('fr'),
      cancelled: 'Repas annulé',
      ended: 'Repas terminé',
    ),
  ]) {
    testWidgets('open -> cancelled updates the bar live (${c.locale})', (
      tester,
    ) async {
      await pump(tester, locale: c.locale);
      expect(join, findsOneWidget);

      await emit(tester, _open.copyWith(status: MealStatus.cancelled));

      expect(join, findsNothing);
      expect(
        find.byKey(const Key('meal_detail_cancelled_button')),
        findsOneWidget,
      );
      expect(find.text(c.cancelled), findsOneWidget);
    });

    testWidgets('open -> completed shows Meal ended live (${c.locale})', (
      tester,
    ) async {
      await pump(tester, locale: c.locale);

      await emit(tester, _open.copyWith(status: MealStatus.completed));

      expect(join, findsNothing);
      expect(find.byKey(const Key('meal_detail_ended_button')), findsOneWidget);
      expect(find.text(c.ended), findsOneWidget);
    });
  }

  testWidgets('an equal snapshot does not rebuild the screen', (tester) async {
    await pump(tester);
    final scaffold = tester.element(find.byType(Scaffold).first);
    final before = scaffold.widget;

    await emit(tester, _open.copyWith());

    expect(tester.element(find.byType(Scaffold).first).widget, same(before));
    expect(join, findsOneWidget);
  });

  testWidgets('a stream error keeps the passed meal', (tester) async {
    await pump(tester);

    meals.controller.addError(StateError('boom'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Cafe Central'), findsOneWidget);
    expect(join, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a deleted/hidden meal keeps the last known one, action '
      'disabled as no longer open', (tester) async {
    await pump(tester);
    await emit(tester, _open.copyWith(note: 'Bring a friend'));
    expect(find.text('Bring a friend'), findsOneWidget);

    await emit(tester, null);

    expect(find.text('Bring a friend'), findsOneWidget);
    expect(join, findsNothing);
    expect(
      find.byKey(const Key('meal_detail_unavailable_button')),
      findsOneWidget,
    );
    expect(find.text('This meal is no longer open.'), findsOneWidget);
  });

  testWidgets('the host keeps their own-meal state when it ends', (
    tester,
  ) async {
    await pump(tester, viewer: 'host1');

    await emit(tester, _open.copyWith(status: MealStatus.completed));

    expect(find.text('This is your meal'), findsOneWidget);
    expect(find.text('Meal ended'), findsNothing);
  });

  for (final locale in const [Locale('en'), Locale('fr')]) {
    testWidgets('ended state: no overflow at 320 px and 2.0x ($locale)', (
      tester,
    ) async {
      await pump(
        tester,
        locale: locale,
        size: const Size(320, 568),
        textScale: 2,
      );
      await emit(tester, _open.copyWith(status: MealStatus.completed));

      expect(find.byKey(const Key('meal_detail_ended_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
