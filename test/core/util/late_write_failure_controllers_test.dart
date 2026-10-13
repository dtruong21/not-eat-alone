import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/util/queued_write.dart';
import 'package:not_eat_alone/core/util/queued_write_failures.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/chat/application/chat_controller.dart';
import 'package:not_eat_alone/features/chat/application/chat_providers.dart';
import 'package:not_eat_alone/features/chat/domain/repositories/chat_repository.dart';
import 'package:not_eat_alone/features/matching/application/create_request_controller.dart';
import 'package:not_eat_alone/features/matching/application/request_providers.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/request_repository.dart';
import 'package:not_eat_alone/features/meal/application/create_meal_controller.dart';
import 'package:not_eat_alone/features/meal/application/meal_providers.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/domain/repositories/meal_repository.dart';
import 'package:not_eat_alone/features/rating/application/rating_controller.dart';
import 'package:not_eat_alone/features/rating/application/rating_providers.dart';
import 'package:not_eat_alone/features/rating/domain/entities/rating.dart';
import 'package:not_eat_alone/features/rating/domain/repositories/rating_repository.dart';

class _Auth extends Mock implements AuthRepository {}

class _Requests extends Mock implements RequestRepository {}

class _Meals extends Mock implements MealRepository {}

class _Ratings extends Mock implements RatingRepository {}

class _Chats extends Mock implements ChatRepository {}

const _restaurant = Restaurant(
  placeId: 'p',
  name: 'Le Comptoir',
  address: '9 rue X, 75006 Paris',
  lat: 48.85,
  lng: 2.33,
);

/// Starts [act] against a write that stays pending past the grace, then
/// rejects it. Nobody listens to the (autoDispose) controller, so it is gone
/// by then: only the app-level notifier can still carry the failure.
void _expectLateFailure(
  FakeAsync async, {
  required Completer<void> server,
  required List<Override> overrides,
  required Future<void> Function(ProviderContainer c) act,
  required QueuedWriteKind expected,
}) {
  final original = debugPrint;
  debugPrint = (m, {wrapWidth}) {};
  addTearDown(() => debugPrint = original);
  {
    final auth = _Auth();
    when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'u1'));
    final c = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth), ...overrides],
    );
    // Subscribed like the app-level listener (keeps the notifier alive).
    c.listen(queuedWriteFailuresProvider, (_, _) {});

    unawaited(act(c));
    async.elapse(queuedWriteGrace + const Duration(seconds: 1));
    expect(
      c.read(queuedWriteFailuresProvider),
      isNull,
      reason: 'nothing reported while pending',
    );

    server.completeError(StateError('permission-denied'));
    async.flushMicrotasks();
    expect(c.read(queuedWriteFailuresProvider)?.kind, expected);
    c.dispose();
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const Rating(
        id: 'a',
        matchId: 'm',
        raterUid: 'u1',
        targetUid: 't',
        stars: 1,
        showedUp: true,
      ),
    );
    registerFallbackValue(
      Meal(
        id: '',
        hostId: 'u1',
        restaurant: _restaurant,
        dateTime: DateTime.utc(2030),
        geohash: '',
      ),
    );
  });

  test('join request reports joinRequest on a late failure', () {
    fakeAsync((async) {
      final server = Completer<void>();
      final repo = _Requests();
      when(
        () => repo.createRequest(
          mealId: any(named: 'mealId'),
          guestId: any(named: 'guestId'),
          hostId: any(named: 'hostId'),
        ),
      ).thenAnswer((_) => server.future);
      _expectLateFailure(
        async,
        server: server,
        overrides: [requestRepositoryProvider.overrideWithValue(repo)],
        act: (c) => c
            .read(createRequestControllerProvider.notifier)
            .request(
              Meal(
                id: 'm1',
                hostId: 'h1',
                restaurant: _restaurant,
                dateTime: DateTime.utc(2030),
                geohash: '',
              ),
            ),
        expected: QueuedWriteKind.joinRequest,
      );
    });
  });

  test('create meal reports meal on a late failure', () {
    fakeAsync((async) {
      final server = Completer<void>();
      final repo = _Meals();
      when(
        () => repo.createMeal(any()),
      ).thenAnswer((_) => server.future.then((_) => 'id'));
      _expectLateFailure(
        async,
        server: server,
        overrides: [mealRepositoryProvider.overrideWithValue(repo)],
        act: (c) => c
            .read(createMealControllerProvider.notifier)
            .create(
              restaurant: _restaurant,
              dateTime: DateTime.utc(2030),
              womenOnly: false,
            ),
        expected: QueuedWriteKind.meal,
      );
    });
  });

  test('rating reports rating on a late failure', () {
    fakeAsync((async) {
      final server = Completer<void>();
      final repo = _Ratings();
      when(() => repo.submit(any())).thenAnswer((_) => server.future);
      _expectLateFailure(
        async,
        server: server,
        overrides: [ratingRepositoryProvider.overrideWithValue(repo)],
        act: (c) => c
            .read(ratingControllerProvider.notifier)
            .submit(matchId: 'm', targetUid: 't', stars: 4, showedUp: true),
        expected: QueuedWriteKind.rating,
      );
    });
  });

  test('chat send reports message on a late failure', () {
    fakeAsync((async) {
      final server = Completer<void>();
      final repo = _Chats();
      when(
        () => repo.sendMessage(
          matchId: any(named: 'matchId'),
          senderId: any(named: 'senderId'),
          text: any(named: 'text'),
        ),
      ).thenAnswer((_) => server.future);
      _expectLateFailure(
        async,
        server: server,
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
        act: (c) => c
            .read(chatControllerProvider.notifier)
            .send(matchId: 'm', text: 'hi'),
        expected: QueuedWriteKind.message,
      );
    });
  });
}
