import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:not_eat_alone/core/location/location_service.dart';

void main() {
  test('permission denied then request stays denied returns parisCenter', () async {
    final service = LocationService(
      checkPermission: () async => LocationPermission.denied,
      requestPermission: () async => LocationPermission.denied,
      getPosition: () async => throw StateError('should not be called'),
    );

    expect(await service.currentOrParis(), parisCenter);
  });

  test('getPosition throws returns parisCenter', () async {
    final service = LocationService(
      checkPermission: () async => LocationPermission.always,
      requestPermission: () async => LocationPermission.always,
      getPosition: () async => throw Exception('location unavailable'),
    );

    expect(await service.currentOrParis(), parisCenter);
  });

  test('granted permission returns device position', () async {
    final stubPosition = Position(
      latitude: 1,
      longitude: 2,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    final service = LocationService(
      checkPermission: () async => LocationPermission.whileInUse,
      requestPermission: () async => LocationPermission.whileInUse,
      getPosition: () async => stubPosition,
    );

    expect(await service.currentOrParis(), (lat: 1.0, lng: 2.0));
  });
}
