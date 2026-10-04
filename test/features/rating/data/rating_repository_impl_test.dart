import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/rating/data/repositories/rating_repository_impl.dart';
import 'package:not_eat_alone/features/rating/domain/entities/rating.dart';

void main() {
  test('submit writes ratings/{matchId}_{raterUid}; watchMyRating reflects it',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = RatingRepositoryImpl(firestore: db);
    await repo.submit(const Rating(
      id: 'm1_u1', matchId: 'm1', raterUid: 'u1', targetUid: 'u2',
      stars: 4, showedUp: true,
    ));
    final snap = await db.collection('ratings').doc('m1_u1').get();
    expect(snap.data()!['stars'], 4);
    expect(snap.data()!['targetUid'], 'u2');
    final mine = await repo.watchMyRating('m1', 'u1').first;
    expect(mine!.stars, 4);
    final none = await repo.watchMyRating('m1', 'uX').first;
    expect(none, isNull);
  });

  test('submit omits comment entirely from the write when null', () async {
    final db = FakeFirebaseFirestore();
    final repo = RatingRepositoryImpl(firestore: db);
    await repo.submit(const Rating(
      id: 'm1_u2', matchId: 'm1', raterUid: 'u2', targetUid: 'u1',
      stars: 4, showedUp: true,
    ));
    final snap = await db.collection('ratings').doc('m1_u2').get();
    // Not just "comment is null" — the KEY must be absent (defense in depth;
    // the rule also accepts null now, see rating_dto.dart).
    expect(snap.data()!.containsKey('comment'), isFalse);
  });
}
