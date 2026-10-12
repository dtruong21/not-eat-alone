import 'dart:async';

import 'package:geolocator/geolocator.dart';

typedef LatLng = ({double lat, double lng});

const parisCenter = (lat: 48.8566, lng: 2.3522);

class LocationService {
  /// Injectable for tests: returns the device position or throws.
  LocationService({
    Future<Position> Function()? getPosition,
    Future<Position?> Function()? getLastKnownPosition,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    this.fixTimeout = defaultFixTimeout,
  }) : _getPosition = getPosition ?? _defaultGetPosition,
       _getLastKnownPosition =
           getLastKnownPosition ?? Geolocator.getLastKnownPosition,
       _checkPermission = checkPermission ?? Geolocator.checkPermission,
       _requestPermission = requestPermission ?? Geolocator.requestPermission;

  /// How long to wait for a GPS/network fix before giving up on it.
  static const defaultFixTimeout = Duration(seconds: 8);

  /// City-level accuracy is plenty (discovery uses a coarse geohash cell and
  /// the manifest only declares coarse location), and it returns far sooner
  /// indoors than a best-accuracy fix.
  static Future<Position> _defaultGetPosition() =>
      Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );

  final Future<Position> Function() _getPosition;
  final Future<Position?> Function() _getLastKnownPosition;
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;
  final Duration fixTimeout;

  /// The device location; if no fix arrives within [fixTimeout], the last
  /// known position; Paris centre on denial or any error. Never hangs: the
  /// discovery feed waits on this, so a missing fix must not become an endless
  /// spinner. (The permission prompt itself is user-paced and is not timed out.)
  Future<LatLng> currentOrParis() async {
    try {
      var perm = await _checkPermission();
      if (perm == LocationPermission.denied) perm = await _requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return parisCenter;
      }
      try {
        final pos = await _getPosition().timeout(fixTimeout);
        return (lat: pos.latitude, lng: pos.longitude);
      } on Object {
        // No fix in time (or the provider failed): a cached position is
        // better than Paris if there is one.
        final last = await _getLastKnownPosition().timeout(
          const Duration(seconds: 2),
        );
        if (last != null) return (lat: last.latitude, lng: last.longitude);
        return parisCenter;
      }
    } catch (_) {
      return parisCenter;
    }
  }
}
