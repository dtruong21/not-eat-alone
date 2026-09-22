import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/notifications/data/push_route_mapper.dart';

void main() {
  test('message payload -> /chats/:matchId', () {
    final r = mapPushData({'type': 'message', 'matchId': 'm1'});
    expect(r!.location, '/chats/m1');
  });
  test('request payload -> /requests', () {
    expect(mapPushData({'type': 'request'})!.location, '/requests');
  });
  test('approved request -> /chats/:mealId', () {
    final r = mapPushData({
      'type': 'request_update',
      'status': 'approved',
      'mealId': 'm9'
    });
    expect(r!.location, '/chats/m9');
  });
  test('denied request -> /discover', () {
    final r = mapPushData({
      'type': 'request_update',
      'status': 'denied',
      'mealId': 'm9'
    });
    expect(r!.location, '/discover');
  });
  test('unknown/missing type -> null', () {
    expect(mapPushData({}), isNull);
    expect(mapPushData({'type': 'nope'}), isNull);
  });
}
