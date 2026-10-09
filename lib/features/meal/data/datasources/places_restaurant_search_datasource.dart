/// `cloud_functions` BOUNDARY for restaurant search. Calls the
/// `searchRestaurants` callable, which proxies Places API (New) server-side so
/// no Places key ships in the app. The callable invocation is behind an
/// injectable seam so tests don't need the plugin (mirrors
/// `AccountRepositoryImpl`).
library;

import 'package:cloud_functions/cloud_functions.dart';

import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/meal/data/dtos/meal_dto.dart';
import 'package:not_eat_alone/features/meal/data/mappers/meal_mapper.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/domain/repositories/restaurant_search_repository.dart';

/// Invokes the `searchRestaurants` callable and returns its response payload.
typedef SearchRestaurantsCallable = Future<Map<String, Object?>> Function(
  String query,
);

class PlacesRestaurantSearchDataSource implements RestaurantSearchRepository {
  PlacesRestaurantSearchDataSource({SearchRestaurantsCallable? callSearch})
    : _callSearch = callSearch ?? _defaultCallSearch;

  final SearchRestaurantsCallable _callSearch;

  static Future<Map<String, Object?>> _defaultCallSearch(String query) async {
    final result = await FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('searchRestaurants').call<Map<Object?, Object?>>({
      'query': query,
    });
    return Map<String, Object?>.from(result.data);
  }

  @override
  Future<List<Restaurant>> search(String query) async {
    final Map<String, Object?> payload;
    try {
      payload = await _callSearch(query.trim());
    } on FirebaseFunctionsException catch (e, s) {
      throw RepositoryReadException('searchRestaurants', e, s);
    }

    try {
      final raw = payload['restaurants'] as List<Object?>? ?? const [];
      return [
        for (final item in raw)
          RestaurantDto.fromJson(
            Map<String, Object?>.from(item! as Map<Object?, Object?>),
          ).toEntity(),
      ];
    } on Object catch (e, s) {
      throw RepositoryParseException('restaurants', 'searchRestaurants', e, s);
    }
  }
}
