import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/matching/application/create_request_controller.dart';
import 'package:not_eat_alone/features/matching/application/inbox_action_controller.dart';
import 'package:not_eat_alone/features/matching/application/request_providers.dart';
import 'package:not_eat_alone/features/matching/data/repositories/meal_no_longer_open_exception.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/request_repository.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';

import '../../../helpers/in_flight_dispose.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockRequestRepository extends Mock implements RequestRepository {}

const _restaurant = Restaurant(
  placeId: 'fake_001',
  name: 'Le Comptoir du Relais',
  address: "9 Carrefour de l'Odéon, 75006 Paris",
  lat: 48.8517,
  lng: 2.3389,
);

final _meal = Meal(
  id: 'meal_1',
  hostId: 'host_1',
  restaurant: _restaurant,
  dateTime: DateTime.utc(2030),
  geohash: '',
);

const _request = JoinRequest(
  id: 'meal_1_guest_1',
  mealId: 'meal_1',
  guestId: 'guest_1',
  hostId: 'host_1',
);

void main() {
  late MockAuthRepository authRepository;
  late MockRequestRepository requestRepository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(_request);
  });

  setUp(() {
    authRepository = MockAuthRepository();
    requestRepository = MockRequestRepository();

    when(() => authRepository.currentUser)
        .thenReturn(const AuthUser(uid: 'guest_1'));
    when(() => requestRepository.createRequest(
          mealId: any(named: 'mealId'),
          guestId: any(named: 'guestId'),
          hostId: any(named: 'hostId'),
        )).thenAnswer((_) async {});
    when(() => requestRepository.approve(any())).thenAnswer((_) async {});
    when(() => requestRepository.deny(any())).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        requestRepositoryProvider.overrideWithValue(requestRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('CreateRequestController', () {
    test(
      'request() calls createRequest with the meal id/hostId and the '
      'current auth uid',
      () async {
        await container
            .read(createRequestControllerProvider.notifier)
            .request(_meal);

        verify(
          () => requestRepository.createRequest(
            mealId: 'meal_1',
            guestId: 'guest_1',
            hostId: 'host_1',
          ),
        ).called(1);

        final state = container.read(createRequestControllerProvider);
        expect(state.hasError, isFalse);
      },
    );
  });

  group('InboxActionController', () {
    test('approve() calls repo.approve and leaves state AsyncData', () async {
      await container
          .read(inboxActionControllerProvider.notifier)
          .approve(_request);

      verify(() => requestRepository.approve(_request)).called(1);

      final state = container.read(inboxActionControllerProvider);
      expect(state.hasError, isFalse);
      expect(state, isA<AsyncData<void>>());
    });

    test(
      'approve() leaves state.hasError true when the meal is no longer open',
      () async {
        when(() => requestRepository.approve(any()))
            .thenThrow(MealNoLongerOpenException('meal_1'));

        await container
            .read(inboxActionControllerProvider.notifier)
            .approve(_request);

        final state = container.read(inboxActionControllerProvider);
        expect(state.hasError, isTrue);
      },
    );

    test('deny() calls repo.deny', () async {
      await container
          .read(inboxActionControllerProvider.notifier)
          .deny(_request);

      verify(() => requestRepository.deny(_request)).called(1);

      final state = container.read(inboxActionControllerProvider);
      expect(state.hasError, isFalse);
    });
  });

  // Regression: the only watcher unmounting mid-action (live E2E: the
  // "Request to join" button is swapped for "Requested" by Firestore latency
  // compensation before the write resolves) used to dispose the autoDispose
  // controller, so the trailing `state =` threw UnmountedRefException and a
  // failure never reached the error listener.
  group('in-flight listener removal', () {
    test('CreateRequestController.request lands AsyncData on the same '
        'instance', () async {
      final gate = Completer<void>();
      when(() => requestRepository.createRequest(
            mealId: any(named: 'mealId'),
            guestId: any(named: 'guestId'),
            hostId: any(named: 'hostId'),
          )).thenAnswer((_) => gate.future);

      final seen = await runWithListenerRemovedMidFlight(
        container,
        createRequestControllerProvider,
        action: () => container
            .read(createRequestControllerProvider.notifier)
            .request(_meal),
        release: gate.complete,
      );

      expect(seen.first.isLoading, isTrue);
      expect(seen.last, isA<AsyncData<void>>());
    });

    test('CreateRequestController.request delivers a failure to a listener '
        'that re-subscribed mid-flight', () async {
      final gate = Completer<void>();
      when(() => requestRepository.createRequest(
            mealId: any(named: 'mealId'),
            guestId: any(named: 'guestId'),
            hostId: any(named: 'hostId'),
          )).thenAnswer((_) => gate.future);

      final seen = await runWithListenerRemovedMidFlight(
        container,
        createRequestControllerProvider,
        action: () => container
            .read(createRequestControllerProvider.notifier)
            .request(_meal),
        release: () => gate.completeError(StateError('denied')),
      );

      expect(seen.first.isLoading, isTrue);
      expect(seen.last.hasError, isTrue);
    });

    test('InboxActionController.approve lands AsyncData on the same '
        'instance', () async {
      final gate = Completer<void>();
      when(() => requestRepository.approve(any()))
          .thenAnswer((_) => gate.future);

      final seen = await runWithListenerRemovedMidFlight(
        container,
        inboxActionControllerProvider,
        action: () => container
            .read(inboxActionControllerProvider.notifier)
            .approve(_request),
        release: gate.complete,
      );

      expect(seen.first.isLoading, isTrue);
      expect(seen.last, isA<AsyncData<void>>());
    });

    test('InboxActionController.approve delivers a failure mid-flight',
        () async {
      final gate = Completer<void>();
      when(() => requestRepository.approve(any()))
          .thenAnswer((_) => gate.future);

      final seen = await runWithListenerRemovedMidFlight(
        container,
        inboxActionControllerProvider,
        action: () => container
            .read(inboxActionControllerProvider.notifier)
            .approve(_request),
        release: () =>
            gate.completeError(MealNoLongerOpenException('meal_1')),
      );

      expect(seen.first.isLoading, isTrue);
      expect(seen.last.hasError, isTrue);
    });

    test('InboxActionController.deny lands AsyncData on the same instance',
        () async {
      final gate = Completer<void>();
      when(() => requestRepository.deny(any()))
          .thenAnswer((_) => gate.future);

      final seen = await runWithListenerRemovedMidFlight(
        container,
        inboxActionControllerProvider,
        action: () => container
            .read(inboxActionControllerProvider.notifier)
            .deny(_request),
        release: gate.complete,
      );

      expect(seen.first.isLoading, isTrue);
      expect(seen.last, isA<AsyncData<void>>());
    });
  });
}
