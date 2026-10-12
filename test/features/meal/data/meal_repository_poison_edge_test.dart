import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/meal/data/repositories/meal_repository_impl.dart';

/// QA sweep 2026-10-12: the `meals` create rule only requires `restaurant is
/// map`. Any signed-in user can therefore store an open, future meal whose
/// restaurant is `{}` (verified in the rules emulator). The Discover query has
/// no client-side tolerance for it: the whole stream errors for every user in
/// the geohash cell, and since clients cannot delete or edit meals the junk
/// document stays until an admin removes it.
/// Bug: docs/bugs/2026-10-12-one-malformed-meal-breaks-discover-for-everyone.md
const _bug =
    'docs/bugs/2026-10-12-one-malformed-meal-breaks-discover-for-everyone.md';

Map<String, Object?> _meal(String id, Object? restaurant) => {
  'id': id,
  'hostId': 'host_$id',
  'restaurant': restaurant,
  'dateTime': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
  'geohash': 'u09tv',
  'note': null,
  'womenOnly': false,
  'seats': 1,
  'status': 'open',
  'guestId': null,
  'createdAt': Timestamp.now(),
};

void main() {
  const goodRestaurant = {
    'placeId': 'p',
    'name': 'Chez X',
    'address': '1 rue Y',
    'lat': 48.85,
    'lng': 2.35,
  };

  test('harness: valid meals stream normally', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('meals/ok').set(_meal('ok', goodRestaurant));
    final meals = await MealRepositoryImpl(
      firestore: db,
    ).watchDiscoverable(geohashPrefix: 'u09').first;
    expect(meals.map((m) => m.id), ['ok']);
  });

  test(
    'a malformed meal document is skipped; the valid ones still stream',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('meals/ok').set(_meal('ok', goodRestaurant));
      await db.doc('meals/junk').set(_meal('junk', <String, Object?>{}));
      final meals = await MealRepositoryImpl(
        firestore: db,
      ).watchDiscoverable(geohashPrefix: 'u09').first;
      expect(meals.map((m) => m.id), ['ok'], reason: _bug);
    },
    skip: 'open bug: $_bug',
  );
}
