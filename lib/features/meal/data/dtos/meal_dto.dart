import 'package:freezed_annotation/freezed_annotation.dart';

part 'meal_dto.freezed.dart';
part 'meal_dto.g.dart';

@freezed
abstract class RestaurantDto with _$RestaurantDto {
  const factory RestaurantDto({
    required String placeId,
    required String name,
    required String address,
    required double lat,
    required double lng,
  }) = _RestaurantDto;

  factory RestaurantDto.fromJson(Map<String, Object?> json) =>
      _$RestaurantDtoFromJson(json);
}

@freezed
abstract class MealDto with _$MealDto {
  const factory MealDto({
    required String id,
    required String hostId,
    required RestaurantDto restaurant,
    required DateTime dateTime,
    required String geohash,
    String? note,
    @Default(false) bool womenOnly,
    @Default(1) int seats,
    @Default('open') String status, // stores MealStatus.name
    String? guestId,
    DateTime? createdAt, // server-set; nullable on optimistic snapshots
  }) = _MealDto;

  factory MealDto.fromJson(Map<String, Object?> json) =>
      _$MealDtoFromJson(json);
}
