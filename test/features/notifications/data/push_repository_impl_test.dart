import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/notifications/data/repositories/push_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  test('registerToken writes users/{uid}/fcmTokens/{token}', () async {
    final repo = PushRepositoryImpl(
      firestore: db,
      readToken: () async => 'tok123',
      requestPermissionFn: () async => true,
      platformName: 'ios',
    );
    await repo.registerToken('u1');
    final snap = await db.collection('users').doc('u1').collection('fcmTokens').doc('tok123').get();
    expect(snap.exists, isTrue);
    expect(snap.data()!['platform'], 'ios');
  });

  test('unregisterCurrentToken deletes the token doc', () async {
    final repo = PushRepositoryImpl(
      firestore: db, readToken: () async => 'tok123',
      requestPermissionFn: () async => true, platformName: 'ios',
    );
    await repo.registerToken('u1');
    await repo.unregisterCurrentToken('u1');
    final snap = await db.collection('users').doc('u1').collection('fcmTokens').doc('tok123').get();
    expect(snap.exists, isFalse);
  });

  test('registerToken no-ops when token is null', () async {
    final repo = PushRepositoryImpl(
      firestore: db, readToken: () async => null,
      requestPermissionFn: () async => true, platformName: 'android',
    );
    await repo.registerToken('u1');
    final all = await db.collection('users').doc('u1').collection('fcmTokens').get();
    expect(all.docs, isEmpty);
  });
}
