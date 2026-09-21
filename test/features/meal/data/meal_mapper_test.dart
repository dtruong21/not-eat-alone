import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/meal/data/dtos/meal_dto.dart';
import 'package:not_eat_alone/features/meal/data/mappers/meal_mapper.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal_status.dart';

void main() {
  final restaurantDto = RestaurantDto(
    placeId: 'p1',
    name: 'Le Petit Bistro',
    address: '1 Rue de Paris',
    lat: 48.8566,
    lng: 2.3522,
  );

  test('dto <-> entity round-trip preserves fields incl. nested restaurant',
      () {
    final dateTime = DateTime.utc(2026, 10, 1, 19, 30);
    final createdAt = DateTime.utc(2026, 9, 21);
    final dto = MealDto(
      id: 'm1',
      hostId: 'u1',
      restaurant: restaurantDto,
      dateTime: dateTime,
      geohash: 'u09tvw',
      note: 'window seat',
      womenOnly: true,
      seats: 2,
      status: 'open',
      guestId: 'u2',
      createdAt: createdAt,
    );

    final entity = dto.toEntity();

    expect(entity.id, 'm1');
    expect(entity.hostId, 'u1');
    expect(entity.restaurant.placeId, 'p1');
    expect(entity.restaurant.name, 'Le Petit Bistro');
    expect(entity.restaurant.address, '1 Rue de Paris');
    expect(entity.restaurant.lat, 48.8566);
    expect(entity.restaurant.lng, 2.3522);
    expect(entity.dateTime, dateTime);
    expect(entity.geohash, 'u09tvw');
    expect(entity.note, 'window seat');
    expect(entity.womenOnly, isTrue);
    expect(entity.seats, 2);
    expect(entity.status, MealStatus.open);
    expect(entity.guestId, 'u2');
    expect(entity.createdAt, createdAt);

    final back = entity.toDto();

    expect(back.id, 'm1');
    expect(back.hostId, 'u1');
    expect(back.restaurant.name, 'Le Petit Bistro');
    expect(back.status, 'open');
    expect(back.womenOnly, isTrue);
  });

  test('unknown status string maps to MealStatus.open', () {
    final dto = MealDto(
      id: 'm1',
      hostId: 'u1',
      restaurant: restaurantDto,
      dateTime: DateTime.utc(2026, 10, 1),
      geohash: 'u09tvw',
      status: 'not-a-real-status',
    );

    final entity = dto.toEntity();

    expect(entity.status, MealStatus.open);
  });
}
