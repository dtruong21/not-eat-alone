import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/util/geohash.dart';

void main() {
  test('encodes the canonical reference point', () {
    expect(encodeGeohash(57.64911, 10.40744, precision: 11), 'u4pruydqqvj');
  });
  test('default precision is 9', () {
    expect(encodeGeohash(57.64911, 10.40744).length, 9);
    expect(encodeGeohash(57.64911, 10.40744), 'u4pruydqq');
  });
  test('prefix property: nearby points share a prefix', () {
    final a = encodeGeohash(48.8584, 2.2945); // Eiffel Tower
    final b = encodeGeohash(48.8600, 2.2950); // ~200m away
    expect(a.substring(0, 5), b.substring(0, 5));
  });
}
