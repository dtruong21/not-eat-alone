import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
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

/// Completes `create()` through a real loading -> data transition so the
/// screen's success listener fires.
class SucceedingCreateMealController extends CreateMealController {
  @override
  Future<void> create({
    required Restaurant restaurant,
    required DateTime dateTime,
    required bool womenOnly,
    String? note,
  }) async {
    state = const AsyncLoading();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    state = const AsyncData(null);
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
      overrides: [createMealControllerProvider.overrideWith(() => controller)],
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
  testWidgets('renders the restaurant name and address', (tester) async {
    final screenKey = GlobalKey<CreateMealScreenState>();
    await pumpScreen(tester, screenKey: screenKey);

    expect(find.text(_restaurant.name), findsOneWidget);
    expect(find.text(_restaurant.address), findsOneWidget);
  });

  testWidgets('the submit button stays disabled until a date/time is chosen', (
    tester,
  ) async {
    final screenKey = GlobalKey<CreateMealScreenState>();
    await pumpScreen(tester, screenKey: screenKey);

    final button = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('create_meal_submit_button')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

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

  testWidgets('an empty note is passed as null', (tester) async {
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
  });

  group('nextMealSlot', () {
    DateTime slot(int h, int m, [int s = 0]) =>
        nextMealSlot(DateTime(2027, 1, 5, h, m, s));

    test('now + 1 h rounded UP to the next :00 or :30', () {
      expect(slot(12, 0), DateTime(2027, 1, 5, 13));
      expect(slot(12, 29), DateTime(2027, 1, 5, 13, 30));
      expect(slot(12, 30), DateTime(2027, 1, 5, 13, 30));
      expect(slot(12, 31), DateTime(2027, 1, 5, 14));
      expect(slot(12, 59), DateTime(2027, 1, 5, 14));
    });

    test('leftover seconds push to the next slot', () {
      expect(slot(12, 0, 30), DateTime(2027, 1, 5, 13, 30));
    });

    test('rolls over midnight', () {
      expect(slot(23, 10), DateTime(2027, 1, 6, 0, 30));
      expect(slot(23, 31), DateTime(2027, 1, 6, 1));
    });

    test('is always at least the minimum lead away', () {
      var t = DateTime(2027, 1, 5, 12);
      for (var i = 0; i < 200; i++) {
        final picked = nextMealSlot(t);
        expect(isMealTimeFarEnough(picked, now: t), isTrue, reason: '$t');
        expect(picked.minute % 30, 0);
        t = t.add(const Duration(minutes: 7, seconds: 13));
      }
    });
  });

  testWidgets('time picker opens on a :00/:30 slot and shows 24 h', (
    tester,
  ) async {
    final screenKey = GlobalKey<CreateMealScreenState>();
    await pumpScreen(tester, screenKey: screenKey);

    await tester.tap(find.byKey(const Key('create_meal_datetime_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final dialog = find.byType(TimePickerDialog);
    expect(dialog, findsOneWidget);
    expect(tester.widget<TimePickerDialog>(dialog).initialTime.minute % 30, 0);
    expect(MediaQuery.of(tester.element(dialog)).alwaysUse24HourFormat, isTrue);
  });

  testWidgets('success snackbar says where requests will show up', (
    tester,
  ) async {
    final screenKey = GlobalKey<CreateMealScreenState>();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              CreateMealScreen(key: screenKey, restaurant: _restaurant),
        ),
        GoRoute(
          path: '/discover',
          builder: (context, state) => const Scaffold(body: Text('discover')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          createMealControllerProvider.overrideWith(
            SucceedingCreateMealController.new,
          ),
        ],
        child: MaterialApp.router(
          theme: buildTheme(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    screenKey.currentState!.debugSetSelectedDateTime(
      DateTime.now().add(const Duration(days: 1)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('create_meal_submit_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(
      find.text("Meal posted. You'll get requests in the Requests tab."),
      findsOneWidget,
    );
    expect(find.text('Meal created!'), findsNothing);
  });

  testWidgets('fits 320x568 at 2.0x text, and Create meal is reachable with '
      'the keyboard up', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final screenKey = GlobalKey<CreateMealScreenState>();
    final controller = FakeCreateMealController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          createMealControllerProvider.overrideWith(() => controller),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: CreateMealScreen(key: screenKey, restaurant: _restaurant),
        ),
      ),
    );
    await tester.pump();
    screenKey.currentState!.debugSetSelectedDateTime(
      DateTime.now().add(const Duration(days: 1)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Keyboard up (~270 px).
    tester.view.viewInsets = const FakeViewPadding(bottom: 270);
    await tester.tap(find.byKey(const Key('create_meal_note_field')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final submit = find.byKey(const Key('create_meal_submit_button'));
    await tester.scrollUntilVisible(
      submit,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    final rect = tester.getRect(submit);
    expect(rect.bottom, lessThanOrEqualTo(568 - 270));
    await tester.tap(submit);
    await tester.pump();
    expect(controller.callCount, 1);
  });

  test('the note field reveals itself above the keyboard', () {
    // Token contract used by the note field's scrollPadding.
    expect(WarmPlayfulSize.keyboardReveal, WarmPlayfulSize.actionHeight * 3);
  });

  group('isMealTimeFarEnough', () {
    final now = DateTime(2027, 1, 5, 12);

    test('accepts a time exactly at the minimum lead and later', () {
      expect(isMealTimeFarEnough(now.add(mealMinLead), now: now), isTrue);
      expect(
        isMealTimeFarEnough(now.add(const Duration(hours: 2)), now: now),
        isTrue,
      );
    });

    test('rejects a time inside the lead, now, and the past', () {
      expect(
        isMealTimeFarEnough(
          now.add(mealMinLead - const Duration(seconds: 1)),
          now: now,
        ),
        isFalse,
      );
      expect(isMealTimeFarEnough(now, now: now), isFalse);
      expect(
        isMealTimeFarEnough(now.subtract(const Duration(minutes: 1)), now: now),
        isFalse,
      );
    });
  });
}
