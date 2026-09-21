import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';

abstract class RestaurantSearchRepository {
  Future<List<Restaurant>> search(String query);
}
