import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/matching/application/request_meal_provider.dart';
import 'package:not_eat_alone/features/meal/application/meal_providers.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/domain/repositories/meal_repository.dart';

class MockMealRepository extends Mock implements MealRepository {}

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

void main() {
  late MockMealRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockMealRepository();
    container = ProviderContainer(
      overrides: [mealRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() => container.dispose());

  test('delegates to MealRepository.getMeal', () async {
    when(() => repository.getMeal('meal_1')).thenAnswer((_) async => _meal);

    final meal = await container.read(requestMealProvider('meal_1').future);

    expect(meal, _meal);
    verify(() => repository.getMeal('meal_1')).called(1);
  });

  test('yields null when the meal does not exist', () async {
    when(() => repository.getMeal('gone')).thenAnswer((_) async => null);

    expect(await container.read(requestMealProvider('gone').future), isNull);
  });

  test('caches per meal id: the same id twice is one repository call',
      () async {
    when(() => repository.getMeal(any())).thenAnswer((_) async => _meal);
    final sub = container.listen(requestMealProvider('meal_1'), (_, _) {});
    addTearDown(sub.close);

    await container.read(requestMealProvider('meal_1').future);
    await container.read(requestMealProvider('meal_1').future);

    verify(() => repository.getMeal('meal_1')).called(1);
  });
}
