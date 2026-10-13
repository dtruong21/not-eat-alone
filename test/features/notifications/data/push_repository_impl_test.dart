import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
    await repo.registerToken('u1', lang: 'en');
    final snap = await db
        .collection('users')
        .doc('u1')
        .collection('fcmTokens')
        .doc('tok123')
        .get();
    expect(snap.exists, isTrue);
    expect(snap.data()!['platform'], 'ios');
  });

  test('unregisterCurrentToken deletes the token doc', () async {
    final repo = PushRepositoryImpl(
      firestore: db,
      readToken: () async => 'tok123',
      requestPermissionFn: () async => true,
      platformName: 'ios',
    );
    await repo.registerToken('u1', lang: 'en');
    await repo.unregisterCurrentToken('u1');
    final snap = await db
        .collection('users')
        .doc('u1')
        .collection('fcmTokens')
        .doc('tok123')
        .get();
    expect(snap.exists, isFalse);
  });

  test('registerToken no-ops when token is null', () async {
    final repo = PushRepositoryImpl(
      firestore: db,
      readToken: () async => null,
      requestPermissionFn: () async => true,
      platformName: 'android',
    );
    await repo.registerToken('u1', lang: 'en');
    final all = await db
        .collection('users')
        .doc('u1')
        .collection('fcmTokens')
        .get();
    expect(all.docs, isEmpty);
  });

  test(
    'registerToken subscribes to refresh stream and writes new tokens',
    () async {
      final controller = StreamController<String>();
      final repo = PushRepositoryImpl(
        firestore: db,
        readToken: () async => 'tok123',
        requestPermissionFn: () async => true,
        platformName: 'ios',
        tokenRefreshStream: controller.stream,
      );
      await repo.registerToken('u1', lang: 'en');

      // Verify initial token is written
      var snap = await db
          .collection('users')
          .doc('u1')
          .collection('fcmTokens')
          .doc('tok123')
          .get();
      expect(snap.exists, isTrue);
      expect(snap.data()!['platform'], 'ios');

      // Emit a refreshed token
      controller.add('tok-new');

      // Wait for the async write to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify the refreshed token is written
      snap = await db
          .collection('users')
          .doc('u1')
          .collection('fcmTokens')
          .doc('tok-new')
          .get();
      expect(snap.exists, isTrue);
      expect(snap.data()!['platform'], 'ios');

      addTearDown(controller.close);
    },
  );

  test(
    'unregisterCurrentToken cancels refresh subscription to prevent stale writes',
    () async {
      final controller = StreamController<String>();
      final repo = PushRepositoryImpl(
        firestore: db,
        readToken: () async => 'tok123',
        requestPermissionFn: () async => true,
        platformName: 'ios',
        tokenRefreshStream: controller.stream,
      );
      await repo.registerToken('u1', lang: 'en');

      // Verify initial token is written
      var snap = await db
          .collection('users')
          .doc('u1')
          .collection('fcmTokens')
          .doc('tok123')
          .get();
      expect(snap.exists, isTrue);

      // Unregister the token
      await repo.unregisterCurrentToken('u1');

      // Verify the initial token is deleted
      snap = await db
          .collection('users')
          .doc('u1')
          .collection('fcmTokens')
          .doc('tok123')
          .get();
      expect(snap.exists, isFalse);

      // Emit a refreshed token after unregister
      controller.add('tok-refreshed');

      // Wait for any potential write
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify the refreshed token is NOT written (subscription was cancelled)
      snap = await db
          .collection('users')
          .doc('u1')
          .collection('fcmTokens')
          .doc('tok-refreshed')
          .get();
      expect(snap.exists, isFalse);

      addTearDown(controller.close);
    },
  );

  group('language', () {
    DocumentReference<Map<String, dynamic>> tokenDoc(String t) =>
        db.collection('users').doc('u1').collection('fcmTokens').doc(t);

    PushRepositoryImpl repoWith({
      String? token = 'tok123',
      Stream<String>? refresh,
    }) => PushRepositoryImpl(
      firestore: db,
      readToken: () async => token,
      requestPermissionFn: () async => true,
      platformName: 'ios',
      tokenRefreshStream: refresh,
    );

    test('registerToken writes lang next to the existing fields', () async {
      await repoWith().registerToken('u1', lang: 'fr');
      final d = (await tokenDoc('tok123').get()).data()!;
      expect(d['lang'], 'fr');
      expect(d['token'], 'tok123');
      expect(d['platform'], 'ios');
      expect(d.containsKey('updatedAt'), isTrue);
    });

    test('unknown languages are stored as en', () async {
      for (final l in ['fr-CA', 'FR', 'de', '']) {
        await repoWith().registerToken('u1', lang: l);
        expect(
          (await tokenDoc('tok123').get()).data()!['lang'],
          'en',
          reason: l,
        );
      }
    });

    test('updateTokenLanguage merges only lang and leaves updatedAt', () async {
      final repo = repoWith();
      await repo.registerToken('u1', lang: 'en');
      final before = (await tokenDoc('tok123').get()).data()!;
      await repo.updateTokenLanguage('u1', 'fr');
      final after = (await tokenDoc('tok123').get()).data()!;
      expect(after['lang'], 'fr');
      expect({...after}..remove('lang'), {...before}..remove('lang'));
    });

    test(
      'updateTokenLanguage does nothing without a token or a token doc',
      () async {
        await repoWith(token: null).updateTokenLanguage('u1', 'fr');
        await repoWith().updateTokenLanguage('u1', 'fr');
        final all = await db
            .collection('users')
            .doc('u1')
            .collection('fcmTokens')
            .get();
        expect(all.docs, isEmpty);
      },
    );

    test(
      'updateTokenLanguage does not resurrect a signed-out token doc',
      () async {
        final repo = repoWith();
        await repo.registerToken('u1', lang: 'en');
        await repo.unregisterCurrentToken('u1');
        await repo.updateTokenLanguage('u1', 'fr');
        expect((await tokenDoc('tok123').get()).exists, isFalse);
      },
    );

    test('a refreshed token carries the CURRENT language', () async {
      final refresh = StreamController<String>();
      addTearDown(refresh.close);
      final repo = repoWith(refresh: refresh.stream);
      await repo.registerToken('u1', lang: 'en');
      await repo.updateTokenLanguage('u1', 'fr');
      refresh.add('tok-new');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect((await tokenDoc('tok-new').get()).data()!['lang'], 'fr');
    });
  });
}
