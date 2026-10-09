import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/meal/data/datasources/places_restaurant_search_datasource.dart';

void main() {
  test('maps the callable payload to Restaurant entities', () async {
    String? sentQuery;
    final dataSource = PlacesRestaurantSearchDataSource(
      callSearch: (query) async {
        sentQuery = query;
        return {
          'restaurants': [
            {
              'placeId': 'abc',
              'name': 'Septime',
              'address': '80 Rue de Charonne, 75011 Paris',
              'lat': 48.8558,
              'lng': 2.3799,
            },
          ],
        };
      },
    );

    final results = await dataSource.search('  septime ');

    expect(sentQuery, 'septime');
    expect(results, hasLength(1));
    expect(results.single.placeId, 'abc');
    expect(results.single.name, 'Septime');
    expect(results.single.lat, 48.8558);
  });

  test('missing restaurants key yields an empty list', () async {
    final dataSource = PlacesRestaurantSearchDataSource(
      callSearch: (query) async => <String, Object?>{},
    );

    expect(await dataSource.search(''), isEmpty);
  });

  test('malformed payload throws RepositoryParseException', () async {
    final dataSource = PlacesRestaurantSearchDataSource(
      callSearch: (query) async => {
        'restaurants': [
          {'placeId': 'abc'},
        ],
      },
    );

    expect(
      dataSource.search('x'),
      throwsA(isA<RepositoryParseException>()),
    );
  });

  test('callable failure throws RepositoryReadException', () async {
    final dataSource = PlacesRestaurantSearchDataSource(
      callSearch: (query) async =>
          throw FirebaseFunctionsException(message: 'boom', code: 'unavailable'),
    );

    expect(
      dataSource.search('x'),
      throwsA(isA<RepositoryReadException>()),
    );
  });
}
