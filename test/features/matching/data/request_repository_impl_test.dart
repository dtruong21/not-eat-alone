import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
// Transitive dependency of fake_cloud_firestore (its documented way to make a
// fake call throw); not worth a direct pubspec entry for these tests.
// ignore: depend_on_referenced_packages
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/matching/data/repositories/request_repository_impl.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';
import 'package:not_eat_alone/features/matching/domain/meal_no_longer_open_exception.dart';

void main() {
  late FakeFirebaseFirestore db;
  late RequestRepositoryImpl repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = RequestRepositoryImpl(firestore: db);
  });

  test('createRequest writes pending with denormalized hostId', () async {
    await repo.createRequest(mealId: 'm1', guestId: 'g1', hostId: 'h1');
    final snap = await db.collection('requests').doc('m1_g1').get();
    expect(snap.data()!['status'], 'pending');
    expect(snap.data()!['hostId'], 'h1');
    expect(snap.data()!['guestId'], 'g1');
  });

  test('watchRequest streams the guest doc then null when absent', () async {
    await repo.createRequest(mealId: 'm1', guestId: 'g1', hostId: 'h1');
    final r = await repo.watchRequest(mealId: 'm1', guestId: 'g1').first;
    expect(r!.status, RequestStatus.pending);
    final none = await repo.watchRequest(mealId: 'm1', guestId: 'gX').first;
    expect(none, isNull);
  });

  test('watchPendingForHost returns only this host pending', () async {
    await repo.createRequest(mealId: 'm1', guestId: 'g1', hostId: 'h1');
    await repo.createRequest(mealId: 'm2', guestId: 'g2', hostId: 'h2');
    final list = await repo.watchPendingForHost('h1').first;
    expect(list.map((r) => r.id), ['m1_g1']);
  });

  test('deny sets a single request to denied', () async {
    await repo.createRequest(mealId: 'm1', guestId: 'g1', hostId: 'h1');
    final r = (await repo.watchRequest(mealId: 'm1', guestId: 'g1').first)!;
    await repo.deny(r);
    final after = await db.collection('requests').doc('m1_g1').get();
    expect(after.data()!['status'], 'denied');
  });

  group('createRequest failure classification', () {
    final denied = FirebaseException(
      plugin: 'firestore',
      code: 'permission-denied',
    );

    Future<Object> classify(
      Object error,
      Future<String?> Function(String) read,
    ) => classifyRequestFailure(
      mealId: 'm1',
      error: error,
      stack: StackTrace.empty,
      readMealStatus: read,
    );

    for (final status in ['cancelled', 'matched', 'completed', null]) {
      test(
        'permission-denied + meal ${status ?? 'missing'} -> no longer open',
        () async {
          expect(
            await classify(denied, (_) async => status),
            isA<MealNoLongerOpenException>().having(
              (e) => e.mealId,
              'mealId',
              'm1',
            ),
          );
        },
      );
    }

    test('permission-denied + meal open -> RepositoryWriteException', () async {
      expect(
        await classify(denied, (_) async => 'open'),
        isA<RepositoryWriteException>().having((e) => e.cause, 'cause', denied),
      );
    });

    test('non permission-denied errors skip the read', () async {
      var reads = 0;
      final result = await classify(
        FirebaseException(plugin: 'firestore', code: 'unavailable'),
        (_) async {
          reads++;
          return 'cancelled';
        },
      );
      expect(result, isA<RepositoryWriteException>());
      expect(
        await classify(StateError('x'), (_) async => null),
        isA<RepositoryWriteException>(),
      );
      expect(reads, 0);
    });

    test('a failing meal read never masks the original error', () async {
      final result = await classify(
        denied,
        (_) async =>
            throw FirebaseException(plugin: 'firestore', code: 'unavailable'),
      );
      expect(
        result,
        isA<RepositoryWriteException>().having((e) => e.cause, 'cause', denied),
      );
    });

    test('createRequest: rules rejection on a cancelled meal', () async {
      await db.collection('meals').doc('m1').set({'status': 'cancelled'});
      whenCalling(
        Invocation.method(#set, null),
      ).on(db.collection('requests').doc('m1_g1')).thenThrow(denied);
      await expectLater(
        repo.createRequest(mealId: 'm1', guestId: 'g1', hostId: 'h1'),
        throwsA(isA<MealNoLongerOpenException>()),
      );
    });

    test(
      'createRequest: rejection on an open meal stays a write failure',
      () async {
        await db.collection('meals').doc('m1').set({'status': 'open'});
        whenCalling(
          Invocation.method(#set, null),
        ).on(db.collection('requests').doc('m1_g1')).thenThrow(denied);
        await expectLater(
          repo.createRequest(mealId: 'm1', guestId: 'g1', hostId: 'h1'),
          throwsA(isA<RepositoryWriteException>()),
        );
      },
    );
  });
}
