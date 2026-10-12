import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/matching/data/repositories/request_repository_impl.dart';

/// QA sweep 2026-10-12: the `requests` create rule has no key/type whitelist
/// (unlike meals, messages, ratings, reports), so a guest can store a request
/// whose `createdAt` is not a server timestamp. `_fromDoc` throws on it and a
/// single such document turns the HOST's whole request inbox into an error
/// state, with no tile to deny it by. The host cannot recover from the client.
/// Bug: docs/bugs/2026-10-12-requests-rule-lets-a-guest-break-the-hosts-inbox.md
const _bug = 'docs/bugs/2026-10-12-requests-rule-lets-a-guest-break-the-hosts-inbox.md';

void main() {
  test('a request with a non-timestamp createdAt does not error the host inbox', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('requests').doc('m1_g1').set({
      'id': 'm1_g1',
      'mealId': 'm1',
      'guestId': 'g1',
      'hostId': 'h1',
      'status': 'pending',
      'createdAt': 'not-a-timestamp',
    });
    final repo = RequestRepositoryImpl(firestore: db);
    List<String>? ids;
    Object? error;
    try {
      ids = (await repo.watchPendingForHost('h1').first).map((r) => r.id).toList();
    } on Object catch (e) {
      error = e;
    }
    expect(error, isNull, reason: 'the whole inbox errors: $_bug');
    expect(ids, isEmpty);
  }, skip: 'open bug: $_bug');
}
