import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:not_eat_alone/core/location/location_service.dart';

/// QA sweep 2026-10-09 (permissions / large-data edge cases): with location
/// permission granted but no GPS fix (indoors, flaky provider) the discovery
/// feed must fall back to Paris instead of spinning forever.
/// Open bug: docs/bugs/2026-10-09-location-fix-has-no-timeout.md
void main() {
  test('permission denied forever falls back to Paris', () async {
    final service = LocationService(
      checkPermission: () async => LocationPermission.deniedForever,
      getPosition: () => throw StateError('must not be called'),
    );
    expect(await service.currentOrParis(), parisCenter);
  });

  test('a position error falls back to Paris', () async {
    final service = LocationService(
      checkPermission: () async => LocationPermission.whileInUse,
      getPosition: () => Future<Position>.error(TimeoutException('no fix')),
    );
    expect(await service.currentOrParis(), parisCenter);
  });

  // BUG docs/bugs/2026-10-09-location-fix-has-no-timeout.md - un-skip when fixed.
  testWidgets('a position that never arrives resolves to Paris within 30s', (
    tester,
  ) async {
    final service = LocationService(
      checkPermission: () async => LocationPermission.whileInUse,
      getPosition: () => Completer<Position>().future,
    );
    LatLng? result;
    unawaited(service.currentOrParis().then((v) => result = v));
    await tester.pump(const Duration(seconds: 30));
    expect(result, parisCenter);
  }, skip: true);
}
