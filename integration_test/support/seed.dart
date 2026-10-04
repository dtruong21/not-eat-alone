/// Firestore preconditions for E2E scenarios, written via the Firestore
/// SDK (not REST) so `firestore.rules` are enforced exactly as in prod —
/// except the `matches` doc in [seedMatch] (see its doc).
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

import 'emulator_admin.dart';

FirebaseFirestore get _db => FirebaseFirestore.instance;

/// Seeds a `users/{uid}` doc satisfying both `firestore.rules` (`uid`,
/// `dob` timestamp, `ageVerified` bool required; `ratingSum`/`ratingCount`/
/// `ratingAvg` must be `0` on create, when present) and `AppUserDto`
/// (`ratingCount`/`ratingAvg` default to `0`; `ratingSum` isn't a DTO field,
/// so it's omitted rather than written — the rules' `get(..., 0)` default
/// matches an absent field). Must run while signed in as [uid].
///
/// Also writes `displayName`/`photoUrls` — not in the brief's original
/// snippet, but `AppUser.profileComplete` (`lib/features/user/domain/
/// entities/app_user.dart`) requires a non-empty `displayName`, a non-empty
/// `photoUrls`, and a non-null `gender` before `routerProvider`'s
/// `authRedirect` (`lib/core/routing/router.dart`) lets a signed-in user
/// past `/onboarding/profile` to `/discover`. Without these two fields the
/// seeded user is stuck on the profile-setup gate — confirmed live in Task
/// 3's smoke test.
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
    'displayName': 'Test User',
    'photoUrls': ['https://example.com/avatar.png'],
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

/// Seeds a pending `requests/{mealId}_{guestId}` doc — the same id shape and
/// field set `RequestRepositoryImpl.createRequest` writes (`lib/features/
/// matching/data/repositories/request_repository_impl.dart`), so it passes
/// the `requests` create rule (open meal, matching hostId, no block,
/// women-only check). Must run while signed in as [guestId]. Returns the
/// request id.
Future<String> seedPendingRequest({
  required String mealId,
  required String guestId,
  required String hostId,
}) async {
  final id = '${mealId}_$guestId';
  await _db.collection('requests').doc(id).set({
    'id': id,
    'mealId': mealId,
    'guestId': guestId,
    'hostId': hostId,
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
  });
  return id;
}

/// Seeds a matched meal plus its `matches/{mealId}` hand-off doc — the end
/// state `RequestRepositoryImpl.approve`'s transaction produces — for
/// scenarios that start post-match (e.g. chat). Must run while signed in as
/// [hostId]: the meal create and `matched` update go through the SDK (rules
/// enforced, host only). The `matches` doc is written through the emulator
/// admin REST API ([adminSetDoc], rules bypassed) because the `matches` create
/// rule requires the approve transaction's other writes.
/// Returns the match id, which is the meal id (`matchId == mealId`
/// throughout the app, e.g. router `/chats/:matchId`).
Future<String> seedMatch({
  required String hostId,
  required String guestId,
  DateTime? dateTime,
}) async {
  final mealId = await seedOpenMeal(hostId: hostId, dateTime: dateTime);
  await _db.collection('meals').doc(mealId).update({
    'status': 'matched',
    'guestId': guestId,
  });
  // Bypasses the `matches` create rule on purpose: since the rule requires the
  // approve transaction's other writes, a bare seed write would be denied. The
  // real approve path is covered by request_match_test.dart and by the
  // rules_enforced_test.dart match-integrity cases.
  await adminSetDoc('matches', mealId, {
    'id': mealId,
    'mealId': mealId,
    'hostId': hostId,
    'guestId': guestId,
    'participants': [hostId, guestId],
    'createdAt': DateTime.now(),
  });
  return mealId;
}
