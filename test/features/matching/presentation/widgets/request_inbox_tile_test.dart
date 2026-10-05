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
  }) async {
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
          child: MaterialApp.router(routerConfig: router),
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

  testWidgets('approving, then the tile being removed from the tree before the '
      'action resolves, does not throw', (tester) async {
    final gate = Completer<void>();
    when(() => requestRepository.approve(any())).thenAnswer((_) => gate.future);

    await pumpTile(tester);
    await tester.tap(find.text('Approve'));
    await tester.pump();

    // Simulate the live inbox list rebuilding without this tile — the
    // request's status already flipped away from "pending" — while
    // `approve()` is still in flight.
    showTile.value = false;
    await tester.pump();

    gate.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

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
        tester.widget<Text>(line).data,
        'Chez Louise · January 5, 2099 at 7:30 PM',
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
}

FilledButton _approveButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.byKey(const Key('request_inbox_approve_button_m1_guest1')),
);

OutlinedButton _denyButton(WidgetTester tester) =>
    tester.widget<OutlinedButton>(
      find.byKey(const Key('request_inbox_deny_button_m1_guest1')),
    );
