/// Hands a [Restaurant] off to the platform maps app ("Open in Maps").
///
/// Link-out only — no Maps SDK and no API key. The launcher is a provider so
/// widget tests inject a fake instead of touching the `url_launcher` plugin.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';

/// Opens [restaurant] in a maps app. Returns `false` when nothing could
/// handle the request; never throws.
typedef MapsLauncher = Future<bool> Function(Restaurant restaurant);

/// Whether [restaurant] has coordinates worth sending to a maps app.
///
/// Missing/legacy data surfaces as `0,0` ("null island") or out-of-range
/// values; those must not produce a button that opens the Atlantic.
bool hasMapsLocation(Restaurant restaurant) {
  final lat = restaurant.lat;
  final lng = restaurant.lng;
  if (!lat.isFinite || !lng.isFinite) return false;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
  return !(lat == 0 && lng == 0);
}

/// Candidate URIs for [restaurant], most native first. The first one the OS
/// can open wins.
@visibleForTesting
List<Uri> mapsUris(Restaurant restaurant, {required bool apple}) {
  final lat = restaurant.lat;
  final lng = restaurant.lng;
  final coords = '$lat,$lng';
  // Parentheses delimit the label in `geo:` URIs.
  final label = restaurant.name.replaceAll(RegExp('[()]'), ' ').trim();

  if (apple) {
    return [
      Uri.https('maps.apple.com', '/', {'ll': coords, 'q': label}),
    ];
  }
  return [
    Uri.parse('geo:$coords?q=$coords(${Uri.encodeComponent(label)})'),
    Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': coords}),
  ];
}

Future<bool> _launchInMaps(Restaurant restaurant) async {
  final apple = switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };
  for (final uri in mapsUris(restaurant, apple: apple)) {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } on Object catch (e) {
      debugPrint('[maps] launch failed for ${uri.scheme}: $e');
    }
  }
  return false;
}

/// Override in tests with a fake [MapsLauncher].
final mapsLauncherProvider = Provider<MapsLauncher>((ref) => _launchInMaps);
