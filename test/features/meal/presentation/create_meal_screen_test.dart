import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/meal/application/create_meal_controller.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/create_meal_screen.dart';

/// Records the `create(...)` call instead of hitting a real
/// [MealRepository]/[AuthRepository] — mirrors `FakeProfileController` in
/// `profile_form_test.dart`. Deliberately doesn't touch `state`, so the
/// screen's success-transition `ref.listen` (which needs a `GoRouter`
/// ancestor via `context.go`) never fires in this test.
class FakeCreateMealController extends CreateMealController {
  Restaurant? calledRestaurant;
  DateTime? calledDateTime;
  String? calledNote;
  bool? calledWomenOnly;
  int callCount = 0;

  @override
  Future<void> create({
    required Restaurant restaurant,
    required DateTime dateTime,
    String? note,
    required bool womenOnly,
  }) async {
    callCount++;
    calledRestaurant = restaurant;
    calledDateTime = dateTime;
    calledNote = note;
    calledWomenOnly = womenOnly;
  }
}

const _restaurant = Restaurant(
  placeId: 'p1',
  name: 'Le Comptoir du Relais',
  address: "9 Carrefour de l'Odéon, 75006 Paris",
  lat: 48.8517,
  lng: 2.3389,
);

Future<FakeCreateMealController> pumpScreen(
  WidgetTester tester, {
  required GlobalKey<CreateMealScreenState> screenKey,
}) async {
  final controller = FakeCreateMealController();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        createMealControllerProvider.overrideWith(() => controller),
      ],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: CreateMealScreen(key: screenKey, restaurant: _restaurant),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();

  return controller;
}

void main() {
  testWidgets(
    'renders the restaurant name and address',
    (tester) async {
      final screenKey = GlobalKey<CreateMealScreenState>();
      await pumpScreen(tester, screenKey: screenKey);

      expect(find.text(_restaurant.name), findsOneWidget);
      expect(find.text(_restaurant.address), findsOneWidget);
    },
  );

  testWidgets(
    'the submit button stays disabled until a date/time is chosen',
    (tester) async {
      final screenKey = GlobalKey<CreateMealScreenState>();
      await pumpScreen(tester, screenKey: screenKey);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('create_meal_submit_button')),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'tapping "Create meal" with an injected date/time calls create() with '
    'the restaurant, date/time, and women-only flag',
    (tester) async {
      final screenKey = GlobalKey<CreateMealScreenState>();
      final controller = await pumpScreen(tester, screenKey: screenKey);

      final chosen = DateTime.now().add(const Duration(days: 3));
      screenKey.currentState!.debugSetSelectedDateTime(chosen);
      await tester.pump();

      await tester.tap(find.byKey(const Key('create_meal_women_only_switch')));
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('create_meal_note_field')),
        'Vegetarian, please!',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('create_meal_submit_button')));
      await tester.pump();
      await tester.pump();

      expect(controller.callCount, 1);
      expect(controller.calledRestaurant, _restaurant);
      expect(controller.calledDateTime, chosen);
      expect(controller.calledWomenOnly, isTrue);
      expect(controller.calledNote, 'Vegetarian, please!');
    },
  );

  testWidgets(
    'an empty note is passed as null',
    (tester) async {
      final screenKey = GlobalKey<CreateMealScreenState>();
      final controller = await pumpScreen(tester, screenKey: screenKey);

      final chosen = DateTime.now().add(const Duration(days: 1));
      screenKey.currentState!.debugSetSelectedDateTime(chosen);
      await tester.pump();

      await tester.tap(find.byKey(const Key('create_meal_submit_button')));
      await tester.pump();
      await tester.pump();

      expect(controller.callCount, 1);
      expect(controller.calledNote, isNull);
      expect(controller.calledWomenOnly, isFalse);
    },
  );
}
