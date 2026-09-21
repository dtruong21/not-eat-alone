import 'package:not_eat_alone/features/meal/data/dtos/meal_dto.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal_status.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';

extension RestaurantDtoX on RestaurantDto {
  Restaurant toEntity() => Restaurant(
        placeId: placeId,
        name: name,
        address: address,
        lat: lat,
        lng: lng,
      );
}

extension RestaurantX on Restaurant {
  RestaurantDto toDto() => RestaurantDto(
        placeId: placeId,
        name: name,
        address: address,
        lat: lat,
        lng: lng,
      );
}

extension MealDtoX on MealDto {
  Meal toEntity() => Meal(
        id: id,
        hostId: hostId,
        restaurant: restaurant.toEntity(),
        dateTime: dateTime,
        geohash: geohash,
        note: note,
        womenOnly: womenOnly,
        seats: seats,
        status: _statusFromString(status),
        guestId: guestId,
        createdAt: createdAt,
      );
}

extension MealX on Meal {
  MealDto toDto() => MealDto(
        id: id,
        hostId: hostId,
        restaurant: restaurant.toDto(),
        dateTime: dateTime,
        geohash: geohash,
        note: note,
        womenOnly: womenOnly,
        seats: seats,
        status: status.name,
        guestId: guestId,
        createdAt: createdAt,
      );
}

MealStatus _statusFromString(String value) {
  try {
    return MealStatus.values.byName(value);
  } on ArgumentError {
    return MealStatus.open;
  }
}
