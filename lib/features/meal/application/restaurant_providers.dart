import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/meal/data/datasources/places_restaurant_search_datasource.dart';
import 'package:not_eat_alone/features/meal/domain/repositories/restaurant_search_repository.dart';

final restaurantSearchRepositoryProvider =
    Provider<RestaurantSearchRepository>(
  (ref) => PlacesRestaurantSearchDataSource(),
);
