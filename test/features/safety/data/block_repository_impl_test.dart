import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:not_eat_alone/features/safety/data/repositories/block_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore db;
  late BlockRepositoryImpl repo;
  setUp(() {
    db = FakeFirebaseFirestore();
    repo = BlockRepositoryImpl(firestore: db);
  });

  test('block writes blocks/{a}_{b} with pair', () async {
    await repo.block('a', 'b');
    final snap = await db.collection('blocks').doc('a_b').get();
    expect(snap.data()!['pair'], ['a', 'b']);
    expect(snap.data()!['blockerUid'], 'a');
  });

  test('watchBlockedUserIds returns the other uid whether I blocked or was '
      'blocked', () async {
    await repo.block('me', 'x'); // I blocked x
    await repo.block('y', 'me'); // y blocked me
    final ids = await repo.watchBlockedUserIds('me').first;
    expect(ids, {'x', 'y'});
  });

  test('unblock deletes my block doc', () async {
    await repo.block('me', 'x');
    await repo.unblock('me', 'x');
    final snap = await db.collection('blocks').doc('me_x').get();
    expect(snap.exists, isFalse);
  });

  group('watchBlockedByMe', () {
    test('only the uids I blocked, not the people who blocked me', () async {
      await repo.block('me', 'x'); // I blocked x
      await repo.block('y', 'me'); // y blocked me
      await repo.block('me', 'z'); // I blocked z
      await repo.block('p', 'q'); // unrelated
      expect(await repo.watchBlockedByMe('me').first, {'x', 'z'});
    });

    test('a block where I am only the blocked side is excluded', () async {
      await repo.block('y', 'me');
      expect(await repo.watchBlockedByMe('me').first, isEmpty);
    });

    test('no blocks: empty set', () async {
      expect(await repo.watchBlockedByMe('me').first, isEmpty);
    });

    test('updates after unblock', () async {
      await repo.block('me', 'x');
      final emissions = <Set<String>>[];
      final sub = repo.watchBlockedByMe('me').listen(emissions.add);
      await Future<void>.delayed(Duration.zero);
      await repo.unblock('me', 'x');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(emissions.first, {'x'});
      expect(emissions.last, isEmpty);
    });
  });
}
