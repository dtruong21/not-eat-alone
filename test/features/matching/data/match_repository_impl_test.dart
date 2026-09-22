import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/matching/data/repositories/match_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore db;
  late MatchRepositoryImpl repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = MatchRepositoryImpl(firestore: db);
    await db.collection('matches').doc('m1').set({
      'id': 'm1', 'mealId': 'm1', 'hostId': 'h1', 'guestId': 'g1',
      'participants': ['h1', 'g1'],
    });
    await db.collection('matches').doc('m2').set({
      'id': 'm2', 'mealId': 'm2', 'hostId': 'h9', 'guestId': 'g9',
      'participants': ['h9', 'g9'],
    });
  });

  test('watchMatchesForUser returns only matches containing the uid', () async {
    final list = await repo.watchMatchesForUser('g1').first;
    expect(list.map((m) => m.id), ['m1']);
    expect(list.single.participants, ['h1', 'g1']);
  });
}
