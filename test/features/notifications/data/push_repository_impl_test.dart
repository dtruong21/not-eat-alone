import 'dart:async';

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

  test('registerToken subscribes to refresh stream and writes new tokens', () async {
    final controller = StreamController<String>();
    final repo = PushRepositoryImpl(
      firestore: db,
      readToken: () async => 'tok123',
      requestPermissionFn: () async => true,
      platformName: 'ios',
      tokenRefreshStream: controller.stream,
    );
    await repo.registerToken('u1');

    // Verify initial token is written
    var snap = await db.collection('users').doc('u1').collection('fcmTokens').doc('tok123').get();
    expect(snap.exists, isTrue);
    expect(snap.data()!['platform'], 'ios');

    // Emit a refreshed token
    controller.add('tok-new');

    // Wait for the async write to complete
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Verify the refreshed token is written
    snap = await db.collection('users').doc('u1').collection('fcmTokens').doc('tok-new').get();
    expect(snap.exists, isTrue);
    expect(snap.data()!['platform'], 'ios');

    addTearDown(controller.close);
  });
}
