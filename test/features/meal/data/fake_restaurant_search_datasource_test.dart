import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/meal/data/datasources/fake_restaurant_search_datasource.dart';

void main() {
  late FakeRestaurantSearchDataSource dataSource;

  setUp(() {
    dataSource = FakeRestaurantSearchDataSource();
  });

  group('FakeRestaurantSearchDataSource', () {
    test('empty query returns the full list', () async {
      final results = await dataSource.search('');

      expect(results.length, greaterThan(10));
    });

    test('query matching a known restaurant name returns it', () async {
      final results = await dataSource.search('Septime');

      expect(results.any((restaurant) => restaurant.name == 'Septime'), isTrue);
    });

    test('nonsense query returns an empty list', () async {
      final results = await dataSource.search('zzzzz');

      expect(results, isEmpty);
    });

    test('search is case-insensitive', () async {
      final upper = await dataSource.search('SEPTIME');
      final lower = await dataSource.search('septime');

      expect(upper, equals(lower));
    });
  });
}
