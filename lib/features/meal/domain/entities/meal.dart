import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal_status.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';

part 'meal.freezed.dart';

@freezed
abstract class Meal with _$Meal {
  const factory Meal({
    required String id,
    required String hostId,
    required Restaurant restaurant,
    required DateTime dateTime,
    required String geohash,
    String? note,
    @Default(false) bool womenOnly,
    @Default(1) int seats,
    @Default(MealStatus.open) MealStatus status,
    String? guestId,
    DateTime? createdAt,
  }) = _Meal;
}
