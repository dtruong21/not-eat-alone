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
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/matching/application/request_providers.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/meal_no_longer_open_exception.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/request_repository.dart';
import 'package:not_eat_alone/features/matching/presentation/widgets/request_inbox_tile.dart';
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
    when(() => userRepository.watch('guest1'))
        .thenAnswer((_) => Stream.value(_guest));
  });

  tearDown(() {
    showTile.dispose();
  });

  Future<void> pumpTile(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requestRepositoryProvider.overrideWithValue(requestRepository),
          userRepositoryProvider.overrideWithValue(userRepository),
        ],
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
  }

  testWidgets(
    'approving, then the tile being removed from the tree before the '
    'action resolves, does not throw',
    (tester) async {
      final gate = Completer<void>();
      when(() => requestRepository.approve(any()))
          .thenAnswer((_) => gate.future);

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
    },
  );

  testWidgets(
    'a MealNoLongerOpenException still shows the snackbar even after the '
    'tile that started the approve was removed from the tree',
    (tester) async {
      final gate = Completer<void>();
      when(() => requestRepository.approve(any()))
          .thenAnswer((_) => gate.future);

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
      when(() => requestRepository.approve(any()))
          .thenThrow(MealNoLongerOpenException('m1'));

      await pumpTile(tester);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(find.text('This meal is no longer open.'), findsOneWidget);
    },
  );
}
