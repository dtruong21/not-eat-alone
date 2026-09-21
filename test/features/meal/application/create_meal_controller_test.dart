import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/meal/application/create_meal_controller.dart';
import 'package:not_eat_alone/features/meal/application/meal_providers.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/domain/repositories/meal_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockMealRepository extends Mock implements MealRepository {}

const _restaurant = Restaurant(
  placeId: 'fake_001',
  name: 'Le Comptoir du Relais',
  address: "9 Carrefour de l'Odéon, 75006 Paris",
  lat: 48.8517,
  lng: 2.3389,
);

/// `analytics.track()` drops to `debugPrint` in debug builds (see
/// `lib/core/analytics/client.dart`) — intercept it here rather than mocking
/// analytics directly, since `track()` isn't provider-wired. [debugPrint] is
/// restored inside a `finally`, synchronously within the test body, mirroring
/// `profile_controller_test.dart`.
Future<List<String>> _captureDebugLogs(Future<void> Function() body) async {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message != null) logs.add(message);
  };
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return logs;
}

void main() {
  late MockAuthRepository authRepository;
  late MockMealRepository mealRepository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(
      Meal(
        id: '',
        hostId: 'h1',
        restaurant: _restaurant,
        dateTime: DateTime.utc(2030),
        geohash: '',
      ),
    );
  });

  setUp(() {
    authRepository = MockAuthRepository();
    mealRepository = MockMealRepository();

    when(() => authRepository.currentUser)
        .thenReturn(const AuthUser(uid: 'h1'));
    when(() => mealRepository.createMeal(any()))
        .thenAnswer((_) async => 'meal_1');

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        mealRepositoryProvider.overrideWithValue(mealRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test(
    'create() calls createMeal with hostId from the current user and fires '
    'meal_created with the passed women_only',
    () async {
      final dateTime = DateTime.utc(2030, 1, 1, 19);

      final logs = await _captureDebugLogs(() async {
        await container.read(createMealControllerProvider.notifier).create(
              restaurant: _restaurant,
              dateTime: dateTime,
              womenOnly: true,
            );
      });

      final captured =
          verify(() => mealRepository.createMeal(captureAny())).captured;
      expect(captured, hasLength(1));
      final meal = captured.single as Meal;
      expect(meal.hostId, 'h1');
      expect(meal.restaurant, _restaurant);
      expect(meal.dateTime, dateTime);
      expect(meal.womenOnly, isTrue);

      expect(
        logs.any(
          (l) => l.contains('meal_created') && l.contains('women_only: true'),
        ),
        isTrue,
      );

      final state = container.read(createMealControllerProvider);
      expect(state.hasError, isFalse);
    },
  );
}
