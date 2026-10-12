import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:not_eat_alone/core/location/location_service.dart';

/// QA sweep 2026-10-09 (permissions / large-data edge cases): with location
/// permission granted but no GPS fix (indoors, flaky provider) the discovery
/// feed must fall back to Paris instead of spinning forever.
/// Fixed: docs/bugs/closed/2026-10-09-location-fix-has-no-timeout.md
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
  });

  Position pos(double lat, double lng) => Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.utc(2026, 10, 12),
    accuracy: 1000,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  testWidgets('no fix in time falls back to the last known position', (
    tester,
  ) async {
    final service = LocationService(
      checkPermission: () async => LocationPermission.whileInUse,
      getPosition: () => Completer<Position>().future,
      getLastKnownPosition: () async => pos(45.76, 4.84),
    );
    LatLng? result;
    unawaited(service.currentOrParis().then((v) => result = v));
    await tester.pump(const Duration(seconds: 30));
    expect(result, (lat: 45.76, lng: 4.84));
  });

  testWidgets('a hanging last-known lookup still ends in Paris', (tester) async {
    final service = LocationService(
      checkPermission: () async => LocationPermission.whileInUse,
      getPosition: () => Completer<Position>().future,
      getLastKnownPosition: () => Completer<Position?>().future,
    );
    LatLng? result;
    unawaited(service.currentOrParis().then((v) => result = v));
    await tester.pump(const Duration(seconds: 30));
    expect(result, parisCenter);
  });

  test('a fix that arrives in time is used', () async {
    final service = LocationService(
      checkPermission: () async => LocationPermission.whileInUse,
      getPosition: () async => pos(48.9, 2.4),
    );
    expect(await service.currentOrParis(), (lat: 48.9, lng: 2.4));
  });
}
