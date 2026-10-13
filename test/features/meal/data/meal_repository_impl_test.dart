import 'dart:async';

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
      },
    );

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

    test('watchDiscoverable emits only open meals whose geohash starts with '
        'the prefix', () async {
      const prefix = 'u09tv';
      final future = DateTime.now().add(const Duration(days: 2));

      Future<void> seed({
        required String id,
        required String status,
        required String geohash,
        DateTime? at,
      }) {
        return firestore.collection('meals').doc(id).set({
          'id': id,
          'hostId': 'host-$id',
          'restaurant': restaurant.toJsonForTest(),
          'dateTime': Timestamp.fromDate(at ?? future),
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
      // (d) open + in-prefix but already started -> should NOT match (the
      // query is time-bounded so expired meals are never downloaded).
      await seed(
        id: 'd',
        status: 'open',
        geohash: '${prefix}def',
        at: DateTime.now().subtract(const Duration(hours: 1)),
      );

      final results = await repository
          .watchDiscoverable(geohashPrefix: prefix)
          .first;

      expect(results.map((m) => m.id), ['a']);
      expect(results.single.status, MealStatus.open);
    });

    test(
      'watchDiscoverable returns soonest first and caps the download',
      () async {
        const prefix = 'u09tv';
        final base = DateTime.now().add(const Duration(days: 1));
        // Seed 105 upcoming meals out of order; the cap keeps the 100 soonest.
        for (var i = 104; i >= 0; i--) {
          await firestore.collection('meals').doc('m$i').set({
            'id': 'm$i',
            'hostId': 'h',
            'restaurant': restaurant.toJsonForTest(),
            'dateTime': Timestamp.fromDate(base.add(Duration(minutes: i))),
            'geohash': '${prefix}x',
            'note': null,
            'womenOnly': false,
            'seats': 1,
            'status': 'open',
            'guestId': null,
            'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
          });
        }

        final results = await repository
            .watchDiscoverable(geohashPrefix: prefix)
            .first;

        expect(results, hasLength(MealRepositoryImpl.discoverableLimit));
        expect(results.first.id, 'm0');
        expect(results.last.id, 'm99');
      },
    );

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

    group('watchMeal', () {
      Map<String, Object?> doc(String status) => {
        'id': 'w1',
        'hostId': 'u1',
        'restaurant': restaurant.toJsonForTest(),
        'dateTime': Timestamp.fromDate(DateTime.utc(2026, 10, 1, 19, 30)),
        'geohash': 'u09tvw',
        'note': null,
        'womenOnly': false,
        'seats': 1,
        'status': status,
        'guestId': null,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9)),
      };

      test('emits the meal, then each change, then null on delete', () async {
        final ref = firestore.collection('meals').doc('w1');
        await ref.set(doc('open'));

        final emitted = <Meal?>[];
        final sub = repository.watchMeal('w1').listen(emitted.add);
        await pumpEventQueue();
        await ref.update({'status': 'cancelled'});
        await pumpEventQueue();
        await ref.delete();
        await pumpEventQueue();
        await sub.cancel();

        expect(emitted.map((m) => m?.status), [
          MealStatus.open,
          MealStatus.cancelled,
          null,
        ]);
        expect(emitted.first!.id, 'w1');
        expect(emitted.first!.restaurant.name, 'Le Petit Bistro');
      });

      test('a missing doc emits null', () async {
        expect(await repository.watchMeal('nope').first, isNull);
      });

      test('permission-denied and not-found emit null; other errors '
          'propagate', () async {
        final source =
            StreamController<DocumentSnapshot<Map<String, dynamic>>>();
        final events = <Object?>[];
        final done = Completer<void>();
        MealRepositoryImpl.mapMealSnapshots(
          'w1',
          source.stream,
        ).listen(events.add, onError: events.add, onDone: done.complete);

        source
          ..addError(FirebaseException(plugin: 'f', code: 'permission-denied'))
          ..addError(FirebaseException(plugin: 'f', code: 'not-found'))
          ..addError(FirebaseException(plugin: 'f', code: 'unavailable'));
        await source.close();
        await done.future;

        expect(events[0], isNull);
        expect(events[1], isNull);
        expect(events[2], isA<FirebaseException>());
        expect((events[2]! as FirebaseException).code, 'unavailable');
      });

      test('a malformed doc is a stream error, not a crash', () async {
        await firestore.collection('meals').doc('bad').set({'hostId': 1});

        await expectLater(
          repository.watchMeal('bad'),
          emitsError(isA<Object>()),
        );
      });
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
