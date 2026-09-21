import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/util/distance.dart';

void main() {
  test('same point is 0', () {
    expect(distanceMeters(48.8566, 2.3522, 48.8566, 2.3522), closeTo(0, 0.001));
  });
  test('one degree of longitude at the equator ~111.32 km', () {
    expect(distanceMeters(0, 0, 0, 1), closeTo(111319, 300));
  });
  test('one degree of latitude ~111.19 km', () {
    expect(distanceMeters(0, 0, 1, 0), closeTo(111194, 300));
  });
}
