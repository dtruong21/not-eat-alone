import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/util/age.dart';

void main() {
  final now = DateTime(2026, 9, 18);
  test('exactly 18 today is adult', () {
    expect(isAdult(DateTime(2008, 9, 18), now: now), true);
  });
  test('one day short of 18 is not adult', () {
    expect(isAdult(DateTime(2008, 9, 19), now: now), false);
  });
  test('well over 18 is adult', () {
    expect(isAdult(DateTime(1990, 1, 1), now: now), true);
  });
}
