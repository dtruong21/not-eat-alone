/// Thrown when a host tries to approve a request on a meal that is no longer
/// `open` (already matched, cancelled, or completed).
class MealNoLongerOpenException implements Exception {
  MealNoLongerOpenException(this.mealId);
  final String mealId;
  @override
  String toString() => 'MealNoLongerOpenException($mealId)';
}
