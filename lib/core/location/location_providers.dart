import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/core/location/location_service.dart';

final locationServiceProvider = Provider((ref) => LocationService());

final locationProvider = FutureProvider<LatLng>(
  (ref) => ref.watch(locationServiceProvider).currentOrParis(),
);
