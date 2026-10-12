import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/meal/application/maps_launcher_provider.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';

Restaurant _at(double lat, double lng, {String name = 'Cafe Central'}) =>
    Restaurant(
      placeId: 'p1',
      name: name,
      address: '1 Rue de Rivoli, 75001 Paris',
      lat: lat,
      lng: lng,
    );

void main() {
  group('hasMapsLocation', () {
    test('true for real Paris coordinates', () {
      expect(hasMapsLocation(_at(48.8566, 2.3522)), isTrue);
    });

    test('false for 0,0 and out-of-range or non-finite values', () {
      expect(hasMapsLocation(_at(0, 0)), isFalse);
      expect(hasMapsLocation(_at(91, 2)), isFalse);
      expect(hasMapsLocation(_at(48, 181)), isFalse);
      expect(hasMapsLocation(_at(double.nan, 2)), isFalse);
    });

    test('true when only one axis is zero', () {
      expect(hasMapsLocation(_at(0, 2.35)), isTrue);
    });
  });

  group('mapsUris', () {
    test('apple: single maps.apple.com URI with ll and encoded name', () {
      final uris = mapsUris(
        _at(48.8566, 2.3522, name: 'Café & Co'),
        apple: true,
      );

      expect(uris, hasLength(1));
      expect(uris.single.host, 'maps.apple.com');
      expect(uris.single.queryParameters['ll'], '48.8566,2.3522');
      expect(uris.single.queryParameters['q'], 'Café & Co');
    });

    test('android: geo URI first, Google Maps web fallback second', () {
      final uris = mapsUris(_at(48.8566, 2.3522), apple: false);

      expect(uris, hasLength(2));
      expect(uris.first.scheme, 'geo');
      expect(uris.first.toString(), startsWith('geo:48.8566,2.3522?q='));
      expect(uris.last.host, 'www.google.com');
      expect(uris.last.queryParameters['query'], '48.8566,2.3522');
    });

    test('parentheses in the name cannot break the geo label', () {
      final uris = mapsUris(
        _at(48.8, 2.3, name: 'Le Bar (Paris)'),
        apple: false,
      );

      expect(uris.first.toString(), contains('(Le%20Bar%20%20Paris)'));
    });
  });
}
