import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/matching/data/repositories/request_repository_impl.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';

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
}
