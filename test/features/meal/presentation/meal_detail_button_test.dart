import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/matching/application/meal_request_state_provider.dart';
import 'package:not_eat_alone/features/matching/application/request_providers.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/request_repository.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/meal_detail_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockRequestRepository extends Mock implements RequestRepository {}

const _restaurant = Restaurant(
  placeId: 'p1',
  name: 'Cafe Central',
  address: '1 Rue de Rivoli, 75001 Paris',
  lat: 48.8566,
  lng: 2.3522,
);

final _meal = Meal(
  id: 'm1',
  hostId: 'host1',
  restaurant: _restaurant,
  dateTime: DateTime(2027, 1, 5, 19, 30),
  geohash: 'u09tvw',
);

final _host = AppUser(uid: 'host1', dob: DateTime(1990, 3, 15));

const _pendingRequest = JoinRequest(
  id: 'm1_guest1',
  mealId: 'm1',
  guestId: 'guest1',
  hostId: 'host1',
);

const _approvedRequest = JoinRequest(
  id: 'm1_guest1',
  mealId: 'm1',
  guestId: 'guest1',
  hostId: 'host1',
  status: RequestStatus.approved,
);

const _deniedRequest = JoinRequest(
  id: 'm1_guest1',
  mealId: 'm1',
  guestId: 'guest1',
  hostId: 'host1',
  status: RequestStatus.denied,
);

void main() {
  late MockUserRepository userRepository;

  setUp(() {
    userRepository = MockUserRepository();
    when(() => userRepository.watch('host1'))
        .thenAnswer((_) => Stream.value(_host));
  });

  Future<void> pumpWith(
    WidgetTester tester, {
    required String viewerUid,
    required JoinRequest? request,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(userRepository),
          authStateProvider.overrideWith(
            (ref) => Stream.value(AuthUser(uid: viewerUid)),
          ),
          mealRequestStateProvider(_meal.id)
              .overrideWith((ref) => Stream.value(request)),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: MealDetailScreen(meal: _meal),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('no request yet -> enabled "Request to join" button',
      (tester) async {
    await pumpWith(tester, viewerUid: 'guest1', request: null);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('meal_detail_request_to_join_button')),
    );
    expect(find.text('Request to join'), findsOneWidget);
    expect(button.onPressed, isNotNull);
  });

  testWidgets('pending request -> disabled "Requested" + host hint',
      (tester) async {
    await pumpWith(tester, viewerUid: 'guest1', request: _pendingRequest);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('meal_detail_requested_button')),
    );
    expect(find.text('Requested'), findsOneWidget);
    expect(button.onPressed, isNull);
    expect(find.text('Waiting for the host'), findsOneWidget);
  });

  testWidgets('approved request -> "Matched!" banner', (tester) async {
    await pumpWith(tester, viewerUid: 'guest1', request: _approvedRequest);

    expect(find.text('Matched!'), findsOneWidget);
    expect(find.text('Tap to start chatting'), findsOneWidget);
  });

  testWidgets('denied request -> disabled "Not selected"', (tester) async {
    await pumpWith(tester, viewerUid: 'guest1', request: _deniedRequest);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('meal_detail_not_selected_button')),
    );
    expect(find.text('Not selected'), findsOneWidget);
    expect(button.onPressed, isNull);
  });

  testWidgets('viewer is the host -> no request button', (tester) async {
    await pumpWith(tester, viewerUid: 'host1', request: null);

    expect(
      find.byKey(const Key('meal_detail_request_to_join_button')),
      findsNothing,
    );
    expect(find.text('Your meal'), findsOneWidget);
  });

  testWidgets(
    'request() failure -> SnackBar, button re-enables',
    (tester) async {
      final authRepository = MockAuthRepository();
      final requestRepository = MockRequestRepository();
      when(() => authRepository.currentUser)
          .thenReturn(const AuthUser(uid: 'guest1'));
      when(
        () => requestRepository.createRequest(
          mealId: any(named: 'mealId'),
          guestId: any(named: 'guestId'),
          hostId: any(named: 'hostId'),
        ),
      ).thenThrow(Exception('network error'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(userRepository),
            authStateProvider.overrideWith(
              (ref) => Stream.value(const AuthUser(uid: 'guest1')),
            ),
            authRepositoryProvider.overrideWithValue(authRepository),
            requestRepositoryProvider.overrideWithValue(requestRepository),
            mealRequestStateProvider(_meal.id)
                .overrideWith((ref) => Stream.value(null)),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: MealDetailScreen(meal: _meal),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('meal_detail_request_to_join_button')),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text("Couldn't send your request. Try again."),
        findsOneWidget,
      );

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('meal_detail_request_to_join_button')),
      );
      expect(button.onPressed, isNotNull);
    },
  );
}
