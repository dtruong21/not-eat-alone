import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';

void main() {
  test('JoinRequest defaults status to pending', () {
    const r = JoinRequest(
      id: 'm1_g1',
      mealId: 'm1',
      guestId: 'g1',
      hostId: 'h1',
    );
    expect(r.status, RequestStatus.pending);
    expect(r.createdAt, isNull);
  });

  test('copyWith flips status', () {
    const r = JoinRequest(
      id: 'm1_g1',
      mealId: 'm1',
      guestId: 'g1',
      hostId: 'h1',
    );
    expect(
      r.copyWith(status: RequestStatus.approved).status,
      RequestStatus.approved,
    );
  });
}
