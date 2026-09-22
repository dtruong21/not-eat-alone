import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/chat/data/repositories/chat_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ChatRepositoryImpl repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = ChatRepositoryImpl(firestore: db);
  });

  test(
    'sendMessage writes under the match subcollection with senderId',
    () async {
      await repo.sendMessage(
        matchId: 'm1',
        senderId: 'u1',
        text: '  hello  ',
      );
      final snap = await db
          .collection('matches')
          .doc('m1')
          .collection('messages')
          .get();
      expect(snap.docs.single.data()['senderId'], 'u1');
      expect(snap.docs.single.data()['text'], 'hello'); // trimmed
    },
  );

  test('sendMessage rejects blank text', () async {
    expect(
      () => repo.sendMessage(matchId: 'm1', senderId: 'u1', text: '   '),
      throwsA(anything),
    );
  });

  test('watchMessages streams oldest-first', () async {
    await repo.sendMessage(matchId: 'm1', senderId: 'u1', text: 'first');
    await repo.sendMessage(matchId: 'm1', senderId: 'u2', text: 'second');
    final msgs = await repo.watchMessages('m1').first;
    expect(msgs.map((m) => m.text), ['first', 'second']);
  });

  test('markRead upserts reads/{uid}; watchRead streams it', () async {
    await repo.markRead(matchId: 'm1', uid: 'u1');
    final r = await repo.watchRead(matchId: 'm1', uid: 'u1').first;
    expect(r!.uid, 'u1');
    expect(r.lastReadAt, isNotNull);
  });
}
