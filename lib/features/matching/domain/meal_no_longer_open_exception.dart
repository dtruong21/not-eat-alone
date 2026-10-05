/// Thrown when a host tries to approve a request on a meal that is no longer
/// `open` (already matched, cancelled, or completed).
class MealNoLongerOpenException implements Exception {
  /// Creates the exception for the meal with id [mealId].
  MealNoLongerOpenException(this.mealId);

  /// Id of the meal that is no longer open.
  final String mealId;
  @override
  String toString() => 'MealNoLongerOpenException($mealId)';
}
