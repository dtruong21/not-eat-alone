import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal_status.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';

void main() {
  const restaurant = Restaurant(
    placeId: 'place-1',
    name: 'Test Restaurant',
    address: '123 Test St',
    lat: 37.7749,
    lng: -122.4194,
  );

  Meal buildMeal() => Meal(
        id: 'meal-1',
        hostId: 'host-1',
        restaurant: restaurant,
        dateTime: DateTime(2026, 9, 21, 12),
        geohash: '9q8yy',
      );

  group('Meal', () {
    test('applies default values', () {
      final meal = buildMeal();

      expect(meal.womenOnly, isFalse);
      expect(meal.seats, 1);
      expect(meal.status, MealStatus.open);
      expect(meal.note, isNull);
      expect(meal.guestId, isNull);
      expect(meal.createdAt, isNull);
      expect(meal.restaurant, restaurant);
    });

    test('copyWith updates fields', () {
      final meal = buildMeal();

      final updated = meal.copyWith(
        seats: 3,
        womenOnly: true,
        status: MealStatus.matched,
        guestId: 'guest-1',
      );

      expect(updated.seats, 3);
      expect(updated.womenOnly, isTrue);
      expect(updated.status, MealStatus.matched);
      expect(updated.guestId, 'guest-1');
      // Untouched fields remain the same.
      expect(updated.id, meal.id);
      expect(updated.hostId, meal.hostId);
      expect(updated.restaurant, meal.restaurant);
    });
  });
}
