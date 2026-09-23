import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/meal/data/repositories/meal_repository_impl.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal_status.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';

void main() {
  group('MealRepositoryImpl', () {
    late FakeFirebaseFirestore firestore;
    late MealRepositoryImpl repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = MealRepositoryImpl(firestore: firestore);
    });

    final restaurant = Restaurant(
      placeId: 'p1',
      name: 'Le Petit Bistro',
      address: '1 Rue de Paris',
      lat: 48.8566,
      lng: 2.3522,
    );

    test(
        'createMeal with empty geohash computes one and persists the doc',
        () async {
      final meal = Meal(
        id: '',
        hostId: 'u1',
        restaurant: restaurant,
        dateTime: DateTime.utc(2026, 10, 1, 19, 30),
        geohash: '',
      );

      final id = await repository.createMeal(meal);

      expect(id, isNotEmpty);

      final snapshot = await firestore.collection('meals').doc(id).get();
      final data = snapshot.data();

      expect(data, isNotNull);
      expect(data!['id'], id);
      expect(data['hostId'], 'u1');
      expect(data['status'], 'open');
      expect(data['geohash'], isNotEmpty);
      expect(data['restaurant'], isA<Map<String, Object?>>());
      expect((data['restaurant']! as Map)['name'], 'Le Petit Bistro');
    });

    test('createMeal persists womenOnly true', () async {
      final meal = Meal(
        id: '',
        hostId: 'u1',
        restaurant: restaurant,
        dateTime: DateTime.utc(2026, 10, 1, 19, 30),
        geohash: '',
        womenOnly: true,
      );

      final id = await repository.createMeal(meal);

      final snapshot = await firestore.collection('meals').doc(id).get();
      final data = snapshot.data();

      expect(data, isNotNull);
      expect(data!['womenOnly'], isTrue);
    });

    test(
        'watchDiscoverable emits only open meals whose geohash starts with '
        'the prefix', () async {
      const prefix = 'u09tv';

      Future<void> seed({
        required String id,
        required String status,
        required String geohash,
      }) {
        return firestore.collection('meals').doc(id).set({
          'id': id,
          'hostId': 'host-$id',
          'restaurant': restaurant.toJsonForTest(),
          'dateTime': Timestamp.fromDate(DateTime.utc(2026, 10, 1, 19, 30)),
          'geohash': geohash,
          'note': null,
          'womenOnly': false,
          'seats': 1,
          'status': status,
          'guestId': null,
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
        });
      }

      // (a) open + geohash starting the prefix -> should match.
      await seed(id: 'a', status: 'open', geohash: '${prefix}xyz');
      // (b) open + a different prefix -> should NOT match.
      await seed(id: 'b', status: 'open', geohash: 'gbsuv12');
      // (c) matched (not open) but in-prefix -> should NOT match.
      await seed(id: 'c', status: 'matched', geohash: '${prefix}abc');

      final results = await repository
          .watchDiscoverable(geohashPrefix: prefix)
          .first;

      expect(results.map((m) => m.id), ['a']);
      expect(results.single.status, MealStatus.open);
    });

    test('getMeal returns the meal for an existing id', () async {
      final meal = Meal(
        id: '',
        hostId: 'u1',
        restaurant: restaurant,
        dateTime: DateTime.utc(2026, 10, 1, 19, 30),
        geohash: '',
      );
      final id = await repository.createMeal(meal);

      final result = await repository.getMeal(id);

      expect(result, isNotNull);
      expect(result!.id, id);
      expect(result.hostId, 'u1');
    });

    test('getMeal returns null when the doc does not exist', () async {
      final result = await repository.getMeal('missing');

      expect(result, isNull);
    });
  });
}

extension on Restaurant {
  Map<String, Object?> toJsonForTest() => {
        'placeId': placeId,
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
      };
}
