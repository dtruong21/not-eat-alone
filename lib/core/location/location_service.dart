import 'package:geolocator/geolocator.dart';

typedef LatLng = ({double lat, double lng});

const parisCenter = (lat: 48.8566, lng: 2.3522);

class LocationService {
  /// Injectable for tests: returns the device position or throws.
  LocationService({
    Future<Position> Function()? getPosition,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
  })  : _getPosition = getPosition ?? (() => Geolocator.getCurrentPosition()),
        _checkPermission = checkPermission ?? Geolocator.checkPermission,
        _requestPermission = requestPermission ?? Geolocator.requestPermission;

  final Future<Position> Function() _getPosition;
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;

  /// The device location, or Paris centre on any denial/error/timeout.
  Future<LatLng> currentOrParis() async {
    try {
      var perm = await _checkPermission();
      if (perm == LocationPermission.denied) perm = await _requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return parisCenter;
      }
      final pos = await _getPosition();
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return parisCenter;
    }
  }
}
