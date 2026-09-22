import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/safety/data/repositories/report_repository_impl.dart';

void main() {
  test('report writes a reports doc', () async {
    final db = FakeFirebaseFirestore();
    final repo = ReportRepositoryImpl(firestore: db);
    await repo.report(reporterId: 'me', targetType: 'user', targetId: 'x', reason: 'spam');
    final snap = await db.collection('reports').get();
    final data = snap.docs.single.data();
    expect(data['reporterId'], 'me');
    expect(data['targetType'], 'user');
    expect(data['targetId'], 'x');
    expect(data['status'], 'open');
  });
}
