import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/chat/presentation/widgets/leave_match_action.dart';
import 'package:not_eat_alone/features/matching/application/match_providers.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/match_repository.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal_status.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/rating/application/match_meal_provider.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';

class _MockMatches extends Mock implements MatchRepository {}

const _restaurant = Restaurant(
  placeId: 'p',
  name: 'Bistro',
  address: 'a',
  lat: 48.85,
  lng: 2.35,
);

Meal _meal({
  MealStatus status = MealStatus.matched,
  Duration fromNow = const Duration(hours: 5),
}) => Meal(
  id: 'm1',
  hostId: 'host',
  guestId: 'guest',
  restaurant: _restaurant,
  dateTime: DateTime.now().add(fromNow),
  geohash: 'u09t',
  status: status,
);

void main() {
  late _MockMatches matches;

  setUp(() {
    matches = _MockMatches();
    when(
      () => matches.cancelMatchedMeal(mealId: any(named: 'mealId')),
    ).thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester, {
    required String uid,
    Meal? meal,
    bool mealLoading = false,
  }) async {
    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(
          path: '/chat',
          builder: (context, state) => Scaffold(
            appBar: AppBar(
              actions: [LeaveMatchAction(matchId: 'm1', otherUid: 'other')],
            ),
            body: const Text('chat'),
          ),
        ),
        GoRoute(
          path: '/chats',
          builder: (context, state) => const Scaffold(body: Text('chats tab')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(AuthUser(uid: uid)),
          ),
          matchMealProvider('m1').overrideWith(
            (ref) =>
                mealLoading ? Completer<Meal?>().future : Future.value(meal),
          ),
          userDocProvider('other').overrideWith(
            (ref) => Stream.value(AppUser(uid: 'other', displayName: 'Sam')),
          ),
          matchRepositoryProvider.overrideWithValue(matches),
        ],
        child: MaterialApp.router(
          theme: buildTheme(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  final button = find.byKey(const Key('leave_match_button'));

  group('visibility', () {
    testWidgets('shown to the host and to the guest of a matched future meal', (
      tester,
    ) async {
      await pump(tester, uid: 'host', meal: _meal());
      expect(button, findsOneWidget);
      await pump(tester, uid: 'guest', meal: _meal());
      expect(button, findsOneWidget);
    });

    testWidgets(
      'hidden when not matched, already started, loading or not a participant',
      (tester) async {
        await pump(
          tester,
          uid: 'host',
          meal: _meal(status: MealStatus.open),
        );
        expect(button, findsNothing);
        await pump(
          tester,
          uid: 'host',
          meal: _meal(status: MealStatus.cancelled),
        );
        expect(button, findsNothing);
        await pump(
          tester,
          uid: 'host',
          meal: _meal(fromNow: const Duration(hours: -1)),
        );
        expect(button, findsNothing);
        await pump(tester, uid: 'host', mealLoading: true);
        expect(button, findsNothing);
        await pump(tester, uid: 'host');
        expect(button, findsNothing);
        await pump(tester, uid: 'stranger', meal: _meal());
        expect(button, findsNothing);
      },
    );
  });

  group('dialog + flow', () {
    testWidgets('host: confirm cancels, tells the user and goes to Chats', (
      tester,
    ) async {
      await pump(tester, uid: 'host', meal: _meal());
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Cancel this meal?'), findsOneWidget);
      expect(find.textContaining('Sam will be told'), findsOneWidget);

      await tester.tap(find.byKey(const Key('leave_match_confirm')));
      await tester.pumpAndSettle();

      verify(() => matches.cancelMatchedMeal(mealId: 'm1')).called(1);
      expect(find.text('Meal cancelled.'), findsOneWidget);
      expect(find.text('chats tab'), findsOneWidget);
    });

    testWidgets('guest: different wording, withdraws', (tester) async {
      await pump(tester, uid: 'guest', meal: _meal());
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Withdraw from this meal?'), findsOneWidget);
      expect(find.textContaining('open up again'), findsOneWidget);

      await tester.tap(find.byKey(const Key('leave_match_confirm')));
      await tester.pumpAndSettle();

      expect(find.text("You've withdrawn."), findsOneWidget);
      expect(find.text('chats tab'), findsOneWidget);
    });

    testWidgets('"Keep meal" changes nothing', (tester) async {
      await pump(tester, uid: 'host', meal: _meal());
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('leave_match_keep')));
      await tester.pumpAndSettle();

      verifyNever(
        () => matches.cancelMatchedMeal(mealId: any(named: 'mealId')),
      );
      expect(find.text('chat'), findsOneWidget);
    });

    testWidgets('failure: error snackbar, stays in the chat', (tester) async {
      when(
        () => matches.cancelMatchedMeal(mealId: any(named: 'mealId')),
      ).thenAnswer((_) async => throw StateError('offline'));
      await pump(tester, uid: 'host', meal: _meal());
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('leave_match_confirm')));
      await tester.pumpAndSettle();

      expect(find.textContaining("Couldn't cancel"), findsOneWidget);
      expect(find.text('chat'), findsOneWidget);
      expect(find.text('chats tab'), findsNothing);
    });

    testWidgets('large text: dialog does not overflow', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, uid: 'host', meal: _meal());
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
