/// Firestore preconditions for E2E scenarios, written via the Firestore
/// SDK (not REST) so `firestore.rules` are enforced exactly as in prod.
///
/// Both helpers write as the CURRENTLY SIGNED-IN user — `firestore.rules`
/// requires `uid == auth.uid` on `users/{uid}` create and
/// `hostId == auth.uid` on `meals/{mealId}` create, so callers must
/// `signInTestUser(uid: ...)` (see `auth.dart`) for the owning uid *before*
/// calling `seedUserProfile`/`seedOpenMeal` for that uid.
///
/// Field sets below were cross-checked against `firebase/firestore.rules`
/// (`match /users/{uid}` and `match /meals/{mealId}` create blocks) and the
/// freezed DTOs `AppUserDto` (`lib/features/user/data/dtos/app_user_dto.dart`)
/// and `MealDto`/`RestaurantDto`
/// (`lib/features/meal/data/dtos/meal_dto.dart`) so seeded docs both pass
/// the rules and deserialize cleanly through the app's repositories.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

FirebaseFirestore get _db => FirebaseFirestore.instance;

/// Seeds a `users/{uid}` doc satisfying both `firestore.rules` (`uid`,
/// `dob` timestamp, `ageVerified` bool required; `ratingSum`/`ratingCount`/
/// `ratingAvg` must be `0` on create, when present) and `AppUserDto`
/// (`ratingCount`/`ratingAvg` default to `0`; `ratingSum` isn't a DTO field,
/// so it's omitted rather than written — the rules' `get(..., 0)` default
/// matches an absent field). Must run while signed in as [uid].
Future<void> seedUserProfile({
  required String uid,
  String gender = 'woman',
  DateTime? dob,
}) async {
  await _db.collection('users').doc(uid).set({
    'uid': uid,
    'dob': Timestamp.fromDate(dob ?? DateTime(1995)),
    'ageVerified': true,
    'gender': gender,
    'ratingCount': 0,
    'ratingAvg': 0,
  });
}

/// Seeds an open `meals/{mealId}` doc satisfying `firestore.rules`
/// (`hostId == auth.uid`, `status`/`geohash` strings, `dateTime` timestamp)
/// and `MealDto` (`restaurant` is a required nested `RestaurantDto` — `id`
/// is NOT written here since `MealRepositoryImpl` injects it from the doc
/// id on read). Must run while signed in as [hostId]. Returns the new
/// document's id.
Future<String> seedOpenMeal({
  required String hostId,
  bool womenOnly = false,
  DateTime? dateTime,
}) async {
  final ref = _db.collection('meals').doc();
  await ref.set({
    'hostId': hostId,
    'status': 'open',
    'geohash': 'u09',
    'dateTime': Timestamp.fromDate(
      dateTime ?? DateTime.now().add(const Duration(hours: 3)),
    ),
    'womenOnly': womenOnly,
    'restaurant': {
      'placeId': 'seed-place-id',
      'name': 'Seed Restaurant',
      'address': '1 Test Street',
      'lat': 48.8566,
      'lng': 2.3522,
    },
  });
  return ref.id;
}
