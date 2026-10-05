import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
// Transitive dependency of fake_cloud_firestore (its documented way to make a
// fake call throw); not worth a direct pubspec entry for this one test.
// ignore: depend_on_referenced_packages
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:not_eat_alone/features/matching/data/repositories/request_repository_impl.dart';
import 'package:not_eat_alone/features/matching/domain/meal_no_longer_open_exception.dart';

void main() {
  late FakeFirebaseFirestore db;
  late RequestRepositoryImpl repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = RequestRepositoryImpl(firestore: db);
    await db.collection('meals').doc('m1').set({
      'id': 'm1', 'hostId': 'h1', 'status': 'open', 'seats': 1,
    });
    await repo.createRequest(mealId: 'm1', guestId: 'g1', hostId: 'h1');
    await repo.createRequest(mealId: 'm1', guestId: 'g2', hostId: 'h1'); // sibling
    await repo.createRequest(mealId: 'm2', guestId: 'g3', hostId: 'h1'); // other meal
  });

  test('approve locks meal, creates match, denies sibling, spares other meal',
      () async {
    final r1 = (await repo.watchRequest(mealId: 'm1', guestId: 'g1').first)!;
    await repo.approve(r1);

    final meal = await db.collection('meals').doc('m1').get();
    expect(meal.data()!['status'], 'matched');
    expect(meal.data()!['guestId'], 'g1');

    final match = await db.collection('matches').doc('m1').get();
    expect(match.exists, isTrue);
    expect(match.data()!['guestId'], 'g1');
    expect(match.data()!['hostId'], 'h1');
    expect(match.data()!['participants'], ['h1', 'g1']);

    final approved = await db.collection('requests').doc('m1_g1').get();
    expect(approved.data()!['status'], 'approved');

    final sibling = await db.collection('requests').doc('m1_g2').get();
    expect(sibling.data()!['status'], 'denied');

    final other = await db.collection('requests').doc('m2_g3').get();
    expect(other.data()!['status'], 'pending'); // untouched
  });

  test('approve on a non-open meal throws and writes nothing', () async {
    await db.collection('meals').doc('m1').update({'status': 'matched'});
    final r1 = (await repo.watchRequest(mealId: 'm1', guestId: 'g1').first)!;
    expect(() => repo.approve(r1), throwsA(isA<MealNoLongerOpenException>()));

    final match = await db.collection('matches').doc('m1').get();
    expect(match.exists, isFalse);

    // The aborted transaction must not have written anything else either:
    // the meal stays 'matched' (its pre-approve value), and both requests
    // stay 'pending' — neither the target nor its sibling got flipped.
    final meal = await db.collection('meals').doc('m1').get();
    expect(meal.data()!['status'], 'matched');

    final request = await db.collection('requests').doc('m1_g1').get();
    expect(request.data()!['status'], 'pending');

    final sibling = await db.collection('requests').doc('m1_g2').get();
    expect(sibling.data()!['status'], 'pending');
  });

  // A sibling whose deny is rejected (in production: decided in the meantime,
  // which the `pending` rule guard refuses) must not abort the rest of the
  // sibling-deny, nor make `approve` throw after the match has committed. The
  // fake is told to throw on the update of g2's request only.
  test('approve still returns, and denies the other siblings, when one '
      "sibling's deny is rejected", () async {
    final rdb = FakeFirebaseFirestore();
    final rrepo = RequestRepositoryImpl(firestore: rdb);
    await rdb.collection('meals').doc('m1').set({
      'id': 'm1',
      'hostId': 'h1',
      'status': 'open',
      'seats': 1,
    });
    for (final g in ['g1', 'g2', 'g4']) {
      await rrepo.createRequest(mealId: 'm1', guestId: g, hostId: 'h1');
    }
    final r1 = (await rrepo.watchRequest(mealId: 'm1', guestId: 'g1').first)!;
    whenCalling(Invocation.method(#update, null))
        .on(rdb.collection('requests').doc('m1_g2'))
        .thenThrow(FirebaseException(plugin: 'firestore', code: 'aborted'));

    await rrepo.approve(r1); // must not throw

    final match = await rdb.collection('matches').doc('m1').get();
    expect(match.exists, isTrue);
    final meal = await rdb.collection('meals').doc('m1').get();
    expect(meal.data()!['status'], 'matched');
    final approved = await rdb.collection('requests').doc('m1_g1').get();
    expect(approved.data()!['status'], 'approved');
    final rejected = await rdb.collection('requests').doc('m1_g2').get();
    expect(rejected.data()!['status'], 'pending'); // its deny was refused
    final other = await rdb.collection('requests').doc('m1_g4').get();
    expect(other.data()!['status'], 'denied'); // still denied
  });
}
