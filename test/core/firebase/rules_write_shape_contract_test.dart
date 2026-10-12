import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:not_eat_alone/features/matching/data/repositories/request_repository_impl.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';
import 'package:not_eat_alone/features/meal/data/repositories/meal_repository_impl.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/rating/data/repositories/rating_repository_impl.dart';
import 'package:not_eat_alone/features/rating/domain/entities/rating.dart';
import 'package:not_eat_alone/features/safety/data/repositories/report_repository_impl.dart';
import 'package:not_eat_alone/features/user/data/repositories/user_repository_impl.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

/// QA sweep 2026-10-12: cross-boundary contract. The tightened Firestore rules
/// accept ONLY a whitelist of keys per document (`keys().hasOnly([...])`); one
/// extra field in a repository write makes every such write PERMISSION_DENIED
/// in production while all Dart tests (fakes have no rules) stay green. This
/// runs each repository's real write against a fake Firestore and checks the
/// stored keys against the whitelist parsed from `firebase/firestore.rules`.
/// The behavioural twin (the same shapes through the rules emulator) is
/// `firebase/rules-test/client_write_shapes.rules.test.cjs`.
void main() {
  final rules = File('firebase/firestore.rules').readAsStringSync();

  /// The first `hasOnly([...])` list after [marker] in the rules file.
  Set<String> whitelistAfter(String marker) {
    final start = rules.indexOf(marker);
    expect(start, greaterThanOrEqualTo(0), reason: 'rules marker $marker');
    final m = RegExp(
      r'hasOnly\(\[([^\]]*)\]\)',
    ).firstMatch(rules.substring(start));
    expect(m, isNotNull, reason: 'no hasOnly after $marker');
    return RegExp(
      r"'([A-Za-z]+)'",
    ).allMatches(m!.group(1)!).map((e) => e.group(1)!).toSet();
  }

  void expectWithin(Set<String> written, Set<String> allowed, String what) {
    expect(written, isNotEmpty, reason: '$what wrote nothing');
    expect(allowed, isNotEmpty, reason: '$what has no whitelist');
    expect(
      written.difference(allowed),
      isEmpty,
      reason: '$what writes keys the rules reject',
    );
  }

  test('negative control: the comparison reports an extra key', () {
    final allowed = whitelistAfter('match /messages/{messageId}');
    expect(allowed, containsAll(['matchId', 'senderId', 'text', 'createdAt']));
    expect({...allowed, 'surprise'}.difference(allowed), {'surprise'});
  });

  test('chat message', () async {
    final db = FakeFirebaseFirestore();
    await ChatRepositoryImpl(
      firestore: db,
    ).sendMessage(matchId: 'm1', senderId: 'u1', text: 'hi');
    final written = (await db.collection('matches/m1/messages').get()).docs
        .single
        .data();
    expectWithin(
      written.keys.toSet(),
      whitelistAfter('match /messages/{messageId}'),
      'sendMessage',
    );
  });

  test('rating (with and without a comment)', () async {
    for (final comment in <String?>[null, 'nice']) {
      final db = FakeFirebaseFirestore();
      await RatingRepositoryImpl(firestore: db).submit(
        Rating(
          id: 'm1_u1',
          matchId: 'm1',
          raterUid: 'u1',
          targetUid: 'u2',
          stars: 4,
          showedUp: true,
          comment: comment,
        ),
      );
      final written = (await db.doc('ratings/m1_u1').get()).data()!;
      expectWithin(
        written.keys.toSet(),
        whitelistAfter('match /ratings/{ratingId}'),
        'rating submit (comment: $comment)',
      );
    }
  });

  test('report', () async {
    final db = FakeFirebaseFirestore();
    await ReportRepositoryImpl(
      firestore: db,
    ).report(reporterId: 'u1', targetType: 'user', targetId: 'u2');
    final written = (await db.collection('reports').get()).docs.single.data();
    expectWithin(
      written.keys.toSet(),
      whitelistAfter('match /reports/{reportId}'),
      'report',
    );
  });

  test('meal create', () async {
    final db = FakeFirebaseFirestore();
    final id = await MealRepositoryImpl(firestore: db).createMeal(
      Meal(
        id: '',
        hostId: 'u1',
        restaurant: const Restaurant(
          placeId: 'p',
          name: 'Chez X',
          address: '1 rue Y',
          lat: 48.85,
          lng: 2.35,
        ),
        dateTime: DateTime.utc(2030),
        geohash: '',
        note: 'hello',
        womenOnly: true,
      ),
    );
    final written = (await db.doc('meals/$id').get()).data()!;
    expectWithin(
      written.keys.toSet(),
      whitelistAfter('match /meals/{mealId}'),
      'createMeal',
    );
  });

  test('approve transaction: the match document', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('meals/m1').set({'id': 'm1', 'hostId': 'h', 'status': 'open'});
    final repo = RequestRepositoryImpl(firestore: db);
    await repo.createRequest(mealId: 'm1', guestId: 'g', hostId: 'h');
    await repo.approve(
      const JoinRequest(
        id: 'm1_g',
        mealId: 'm1',
        guestId: 'g',
        hostId: 'h',
        status: RequestStatus.pending,
      ),
    );
    final written = (await db.doc('matches/m1').get()).data()!;
    expectWithin(
      written.keys.toSet(),
      whitelistAfter('match /matches/{matchId}'),
      'approve (matches doc)',
    );
    // The meal update may only touch these two fields (rules: affectedKeys).
    final meal = (await db.doc('meals/m1').get()).data()!;
    expect(meal['status'], 'matched');
    expect(meal['guestId'], 'g');
  });

  test('private user and public profile writes', () async {
    final db = FakeFirebaseFirestore();
    final repo = UserRepositoryImpl(firestore: db);
    await repo.upsertAgeVerified(uid: 'u1', dob: DateTime.utc(1990));
    await repo.updateProfile(
      uid: 'u1',
      displayName: 'Ada',
      photoUrls: ['https://x/1.jpg'],
      bio: 'hi',
      gender: Gender.woman,
    );
    final private = (await db.doc('users/u1').get()).data()!;
    final public = (await db.doc('profiles/u1').get()).data()!;
    expectWithin(
      private.keys.toSet(),
      whitelistAfter('match /users/{uid}'),
      'users/{uid}',
    );
    expectWithin(
      public.keys.toSet(),
      whitelistAfter('function profileShapeOk'),
      'profiles/{uid}',
    );
  });
}
