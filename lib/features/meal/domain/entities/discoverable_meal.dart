import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';

part 'discoverable_meal.freezed.dart';

/// A [Meal] paired with the viewer's distance to its restaurant — the view
/// model discovery screens render.
///
/// Pure (no Firestore, no analytics): built by `discoveryControllerProvider`
/// from a raw [Meal] plus the viewer's resolved location.
@freezed
abstract class DiscoverableMeal with _$DiscoverableMeal {
  const factory DiscoverableMeal({
    required Meal meal,
    required double distanceMeters,
  }) = _DiscoverableMeal;
}
