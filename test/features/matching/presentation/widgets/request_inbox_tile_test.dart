/// Regression: `RequestInboxTile._approve` used to `ref.read` the
/// controller's state a second time AFTER the awaited `approve()` call, to
/// decide whether to show the "no longer open" snackbar. If the tile was
/// removed from the tree while that call was still in flight — exactly what
/// happens live once the request's own status flip is applied optimistically
/// by the Firestore SDK, before `approve()`'s enclosing future resolves —
/// that second `ref.read` threw `Bad state: Using "ref" ... unmounted`. Fixed
/// by having `InboxActionController.approve` RETURN the outcome so the tile
/// never touches `ref`/`context` after the await; the `ScaffoldMessenger` is
/// captured before the await instead, since it's an ANCESTOR that survives
/// the tile's own removal.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/util/date_format.dart';
import 'package:not_eat_alone/features/matching/application/request_meal_provider.dart';
import 'package:not_eat_alone/features/matching/application/request_providers.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/meal_no_longer_open_exception.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/request_repository.dart';
import 'package:not_eat_alone/features/matching/presentation/widgets/request_inbox_tile.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

class MockRequestRepository extends Mock implements RequestRepository {}

class MockUserRepository extends Mock implements UserRepository {}

const _request = JoinRequest(
  id: 'm1_guest1',
  mealId: 'm1',
  guestId: 'guest1',
  hostId: 'host1',
);

final _guest = AppUser(
  uid: 'guest1',
  dob: DateTime(1995, 1, 1),
  displayName: 'Amélie',
);

const _restaurant = Restaurant(
  placeId: 'p1',
  name: 'Chez Louise',
  address: '1 Rue X',
  lat: 0,
  lng: 0,
);

Meal _meal(DateTime dateTime) => Meal(
  id: 'm1',
  hostId: 'host1',
  restaurant: _restaurant,
  dateTime: dateTime,
  geohash: 'abc',
);

/// flutter_test renders every glyph 1em wide (the Ahem font), roughly 1.8x
/// wider than the app's real Nunito (~0.55em average advance). Scale the font
/// sizes down so line breaks in layout tests resemble the real app.
ThemeData _nunitoLike(ThemeData theme) {
  TextStyle? shrink(TextStyle? style, double fallback) =>
      style?.copyWith(fontSize: (style.fontSize ?? fallback) * 0.55);
  final t = theme.textTheme;
  return theme.copyWith(
    textTheme: t.copyWith(
      bodySmall: shrink(t.bodySmall, 12),
      bodyMedium: shrink(t.bodyMedium, 14),
      labelLarge: shrink(t.labelLarge, 14),
    ),
    // The theme bakes the button label style in at build time.
    filledButtonTheme: FilledButtonThemeData(
      style: theme.filledButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(shrink(t.labelLarge, 14)),
      ),
    ),
  );
}

final Meal _futureMeal = _meal(DateTime(2099, 1, 5, 19, 30));
final Meal _pastMeal = _meal(DateTime(2020, 1, 5, 19, 30));

void main() {
  late MockRequestRepository requestRepository;
  late MockUserRepository userRepository;
  late ValueNotifier<bool> showTile;

  setUpAll(() {
    registerFallbackValue(_request);
  });

  setUp(() {
    requestRepository = MockRequestRepository();
    userRepository = MockUserRepository();
    showTile = ValueNotifier<bool>(true);
    when(
      () => userRepository.watch('guest1'),
    ).thenAnswer((_) => Stream.value(_guest));
  });

  tearDown(() {
    showTile.dispose();
  });

  Future<void> pumpTile(
    WidgetTester tester, {
    AsyncValue<Meal?>? meal,
    bool withRouter = false,
    List<String>? pushed,
    ThemeData? theme,
    double textScale = 1,
  }) async {
    Widget scaled(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    );
    final overrides = [
      requestRepositoryProvider.overrideWithValue(requestRepository),
      userRepositoryProvider.overrideWithValue(userRepository),
      requestMealProvider('m1').overrideWith(
        (ref) => switch (meal ?? AsyncData<Meal?>(_futureMeal)) {
          AsyncData(:final value) => Future<Meal?>.value(value),
          AsyncError(:final error) => Future<Meal?>.error(error),
          _ => Completer<Meal?>().future,
        },
      ),
    ];
    final tileBody = Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: showTile,
        builder: (context, show, _) => show
            ? const RequestInboxTile(request: _request)
            : const SizedBox.shrink(),
      ),
    );
    if (withRouter) {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => tileBody),
          GoRoute(
            path: '/chats/:matchId',
            builder: (_, state) {
              pushed?.add(state.uri.toString());
              return const Scaffold(body: Text('chat screen'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp.router(
            routerConfig: router,
            theme: theme,
            builder: scaled,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return;
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: theme,
          builder: scaled,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: showTile,
              builder: (context, show, _) => show
                  ? const RequestInboxTile(request: _request)
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'a MealNoLongerOpenException still shows the snackbar even after the '
    'tile that started the approve was removed from the tree',
    (tester) async {
      final gate = Completer<void>();
      when(
        () => requestRepository.approve(any()),
      ).thenAnswer((_) => gate.future);

      await pumpTile(tester);
      await tester.tap(find.text('Approve'));
      await tester.pump();

      showTile.value = false;
      await tester.pump();

      gate.completeError(MealNoLongerOpenException('m1'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('This meal is no longer open.'), findsOneWidget);
    },
  );

  testWidgets(
    'a MealNoLongerOpenException shows the snackbar when the tile is still '
    'mounted (baseline, no removal)',
    (tester) async {
      when(
        () => requestRepository.approve(any()),
      ).thenThrow(MealNoLongerOpenException('m1'));

      await pumpTile(tester);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(find.text('This meal is no longer open.'), findsOneWidget);
    },
  );

  group('meal line', () {
    testWidgets('shows restaurant and date/time on data', (tester) async {
      await pumpTile(tester);

      final line = find.byKey(const Key('request_inbox_meal_line_m1_guest1'));
      expect(line, findsOneWidget);
      expect(
        find.descendant(of: line, matching: find.text('Chez Louise')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: line,
          matching: find.text(formatMealDateTime(_futureMeal.dateTime)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders nothing extra while loading', (tester) async {
      await pumpTile(tester, meal: const AsyncLoading());

      expect(
        find.byKey(const Key('request_inbox_meal_line_m1_guest1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('request_inbox_past_chip_m1_guest1')),
        findsNothing,
      );
      expect(_approveButton(tester).onPressed, isNotNull);
    });

    testWidgets('renders nothing extra on error', (tester) async {
      await pumpTile(
        tester,
        meal: AsyncError<Meal?>(Exception('boom'), StackTrace.empty),
      );

      expect(
        find.byKey(const Key('request_inbox_meal_line_m1_guest1')),
        findsNothing,
      );
      expect(_approveButton(tester).onPressed, isNotNull);
    });

    testWidgets('renders nothing extra when the meal is missing', (
      tester,
    ) async {
      await pumpTile(tester, meal: const AsyncData<Meal?>(null));

      expect(
        find.byKey(const Key('request_inbox_meal_line_m1_guest1')),
        findsNothing,
      );
      expect(_approveButton(tester).onPressed, isNotNull);
    });
  });

  group('past meal', () {
    testWidgets('shows the chip, disables Approve, keeps Deny enabled', (
      tester,
    ) async {
      await pumpTile(tester, meal: AsyncData<Meal?>(_pastMeal));

      expect(find.text('Meal time has passed'), findsOneWidget);
      expect(
        find.byKey(const Key('request_inbox_past_chip_m1_guest1')),
        findsOneWidget,
      );
      expect(_approveButton(tester).onPressed, isNull);
      expect(_denyButton(tester).onPressed, isNotNull);
    });

    testWidgets('a future meal has no chip and Approve is enabled', (
      tester,
    ) async {
      await pumpTile(tester);

      expect(
        find.byKey(const Key('request_inbox_past_chip_m1_guest1')),
        findsNothing,
      );
      expect(_approveButton(tester).onPressed, isNotNull);
      expect(_denyButton(tester).onPressed, isNotNull);
    });
  });

  group('outcome feedback', () {
    testWidgets('approve success shows the message with a Chat action that '
        'pushes /chats/m1', (tester) async {
      when(() => requestRepository.approve(any())).thenAnswer((_) async {});
      final pushed = <String>[];

      await pumpTile(tester, withRouter: true, pushed: pushed);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(find.text('Approved. You can chat now.'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);

      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();

      expect(find.text('chat screen'), findsOneWidget);
      expect(pushed, ['/chats/m1']);
    });

    testWidgets('approve generic failure shows the generic message, no Chat', (
      tester,
    ) async {
      when(
        () => requestRepository.approve(any()),
      ).thenThrow(Exception('permission-denied'));

      await pumpTile(tester);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Couldn't approve this request. It may already have been handled.",
        ),
        findsOneWidget,
      );
      expect(find.text('Chat'), findsNothing);
    });

    testWidgets('deny success shows "Request denied."', (tester) async {
      when(() => requestRepository.deny(any())).thenAnswer((_) async {});

      await pumpTile(tester);
      await tester.tap(find.text('Deny'));
      await tester.pumpAndSettle();

      expect(find.text('Request denied.'), findsOneWidget);
      expect(find.text('Chat'), findsNothing);
    });

    testWidgets('deny failure shows the generic deny message', (tester) async {
      when(
        () => requestRepository.deny(any()),
      ).thenThrow(Exception('permission-denied'));

      await pumpTile(tester);
      await tester.tap(find.text('Deny'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Couldn't deny this request. It may already have been handled.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('unmounting mid-flight on approve still shows the snackbar', (
      tester,
    ) async {
      final gate = Completer<void>();
      when(
        () => requestRepository.approve(any()),
      ).thenAnswer((_) => gate.future);

      await pumpTile(tester);
      await tester.tap(find.text('Approve'));
      await tester.pump();

      showTile.value = false;
      await tester.pump();

      gate.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Approved. You can chat now.'), findsOneWidget);
    });

    testWidgets('unmounting mid-flight on deny still shows the snackbar', (
      tester,
    ) async {
      final gate = Completer<void>();
      when(() => requestRepository.deny(any())).thenAnswer((_) => gate.future);

      await pumpTile(tester);
      await tester.tap(find.text('Deny'));
      await tester.pump();

      showTile.value = false;
      await tester.pump();

      gate.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Request denied.'), findsOneWidget);
    });
  });

  group('outcome feedback (persistence and edge cases)', () {
    testWidgets('the approve snackbar auto-dismisses', (tester) async {
      when(() => requestRepository.approve(any())).thenAnswer((_) async {});

      await pumpTile(tester);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(find.text('Approved. You can chat now.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Approved. You can chat now.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Approved. You can chat now.'), findsNothing);
    });

    testWidgets('a new outcome replaces the previous snackbar', (tester) async {
      when(() => requestRepository.approve(any())).thenAnswer((_) async {});
      when(() => requestRepository.deny(any())).thenAnswer((_) async {});

      await pumpTile(tester);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(find.text('Approved. You can chat now.'), findsOneWidget);

      await tester.tap(find.text('Deny'));
      await tester.pumpAndSettle();

      expect(find.text('Request denied.'), findsOneWidget);
      expect(find.text('Approved. You can chat now.'), findsNothing);
    });

    testWidgets('the Chat action still navigates after the tile unmounted '
        'mid-flight', (tester) async {
      final gate = Completer<void>();
      when(
        () => requestRepository.approve(any()),
      ).thenAnswer((_) => gate.future);
      final pushed = <String>[];

      await pumpTile(tester, withRouter: true, pushed: pushed);
      await tester.tap(find.text('Approve'));
      await tester.pump();

      showTile.value = false;
      await tester.pump();

      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(SnackBarAction, 'Chat'));
      await tester.pumpAndSettle();

      expect(pushed, ['/chats/m1']);
    });

    testWidgets('without a router the Chat action is not offered', (
      tester,
    ) async {
      when(() => requestRepository.approve(any())).thenAnswer((_) async {});

      await pumpTile(tester);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(find.text('Approved. You can chat now.'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'Chat'), findsNothing);
    });

    testWidgets('while an action is in flight both buttons are disabled', (
      tester,
    ) async {
      final gate = Completer<void>();
      when(
        () => requestRepository.approve(any()),
      ).thenAnswer((_) => gate.future);

      await pumpTile(tester);
      await tester.tap(find.text('Approve'));
      await tester.pump();

      expect(_approveButton(tester).onPressed, isNull);
      expect(_denyButton(tester).onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a past meal can still be denied', (tester) async {
      when(() => requestRepository.deny(any())).thenAnswer((_) async {});

      await pumpTile(tester, meal: AsyncData<Meal?>(_pastMeal));
      await tester.tap(find.text('Deny'));
      await tester.pumpAndSettle();

      expect(find.text('Request denied.'), findsOneWidget);
    });

    testWidgets('a disabled Approve explains why (tooltip + semantics)', (
      tester,
    ) async {
      await pumpTile(tester, meal: AsyncData<Meal?>(_pastMeal));

      final approve = find.byKey(
        const Key('request_inbox_approve_button_m1_guest1'),
      );
      expect(
        find.ancestor(of: approve, matching: find.byType(Tooltip)),
        findsOneWidget,
      );
      final node = tester.getSemantics(approve);
      expect(node.hint, 'Meal time has passed');
      expect(node.label, contains('Approve'));
    });
  });

  group('layout', () {
    final longName = 'Le Très Long Nom De Restaurant Gastronomique ' * 3;

    for (final width in [320.0, 360.0]) {
      testWidgets(
        'past meal with a very long name at ${width.toInt()}px and 1.3x text '
        'scale: no overflow, chip on one line, date visible',
        (tester) async {
          tester.view
            ..physicalSize = Size(width, 640)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final meal = Meal(
            id: 'm1',
            hostId: 'host1',
            restaurant: _restaurant.copyWith(name: longName),
            dateTime: DateTime(2020, 1, 5, 19, 30),
            geohash: 'abc',
          );
          await pumpTile(
            tester,
            meal: AsyncData<Meal?>(meal),
            theme: _nunitoLike(buildTheme(Brightness.light)),
            textScale: 1.3,
          );

          expect(tester.takeException(), isNull);

          // Date/time is fully shown on its own line.
          final date = find.text(formatMealDateTime(meal.dateTime));
          expect(date, findsOneWidget);
          final dateText = tester.widget<Text>(date);
          final restaurant = find.text(longName);
          expect(tester.widget<Text>(restaurant).maxLines, 1);
          expect(
            tester.getSize(restaurant).height,
            lessThan(tester.getSize(date).height * 1.5),
            reason: 'the restaurant must be a single (ellipsized) line',
          );
          expect(dateText.maxLines, isNull);

          // Chip label on exactly one line: same height as a one-line layout.
          final label = find.text('Meal time has passed');
          final style = tester.widget<Text>(label).style!;
          final painter = TextPainter(
            text: TextSpan(text: 'Meal time has passed', style: style),
            textDirection: TextDirection.ltr,
            textScaler: const TextScaler.linear(1.3),
          )..layout();
          expect(tester.getSize(label).height, closeTo(painter.height, 1));

          // Both buttons stay inside the screen.
          final tileRect = tester.getRect(
            find.byKey(const Key('request_inbox_tile_m1_guest1')),
          );
          for (final key in [
            'request_inbox_approve_button_m1_guest1',
            'request_inbox_deny_button_m1_guest1',
          ]) {
            final r = tester.getRect(find.byKey(Key(key)));
            expect(r.right, lessThanOrEqualTo(tileRect.right));
            expect(r.left, greaterThanOrEqualTo(tileRect.left));
          }
        },
      );
    }
  });

  group('contrast', () {
    double ratio(Color a, Color b) {
      final l1 = a.computeLuminance();
      final l2 = b.computeLuminance();
      final hi = l1 > l2 ? l1 : l2;
      final lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final brightness in Brightness.values) {
      test('meal line and chip text reach 4.5:1 in ${brightness.name}', () {
        final scheme = buildTheme(brightness).colorScheme;
        final mealLine = ratio(
          scheme.onSurface,
          scheme.surfaceContainerHighest,
        );
        final chip = ratio(scheme.onErrorContainer, scheme.errorContainer);
        // Measured: meal line 11.79 (light) / 13.29 (dark); chip 7.24 both;
        // the old `outline` colour was 1.15 / 1.22.
        expect(mealLine, greaterThanOrEqualTo(4.5));
        expect(chip, greaterThanOrEqualTo(4.5));
      });
    }
  });
}

FilledButton _approveButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.byKey(const Key('request_inbox_approve_button_m1_guest1')),
);

OutlinedButton _denyButton(WidgetTester tester) =>
    tester.widget<OutlinedButton>(
      find.byKey(const Key('request_inbox_deny_button_m1_guest1')),
    );
