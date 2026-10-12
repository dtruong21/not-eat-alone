// Mocks of the sealed Firestore Query types are the only way to observe the
// query shape (fake_cloud_firestore accepts any shape).
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:not_eat_alone/features/safety/data/repositories/block_repository_impl.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

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

    // fake_cloud_firestore accepts any query shape, but the `blocks` rule
    // (`request.auth.uid in resource.data.pair`) only lets production prove
    // `pair array-contains uid`: a `blockerUid ==` query would be denied.
    test('queries by `pair` array-contains (the only shape the rules allow)', () {
      final firestore = _MockFirestore();
      final collection = _MockCollection();
      final query = _MockQuery();
      when(() => firestore.collection('blocks')).thenReturn(collection);
      when(
        () => collection.where('pair', arrayContains: 'me'),
      ).thenReturn(query);
      when(query.snapshots).thenAnswer((_) => const Stream.empty());

      BlockRepositoryImpl(firestore: firestore).watchBlockedByMe('me');

      verify(() => collection.where('pair', arrayContains: 'me')).called(1);
      verifyNever(
        () => collection.where(
          any(),
          isEqualTo: any(named: 'isEqualTo'),
        ),
      );
    });
  });
}
