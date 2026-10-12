import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/meal/application/maps_launcher_provider.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';

Restaurant _named(String name, {double lat = 48.8566, double lng = 2.3522}) =>
    Restaurant(
      placeId: 'p1',
      name: name,
      address: '1 Rue de Rivoli, 75001 Paris',
      lat: lat,
      lng: lng,
    );

/// Pulls the label out of `geo:<lat>,<lng>?q=<lat>,<lng>(<label>)` the way an
/// Android maps app would: take what is between the LAST `(` and the final
/// `)`, then percent-decode.
String _geoLabel(Uri uri) {
  final raw = uri.toString();
  final open = raw.lastIndexOf('(');
  expect(raw.endsWith(')'), isTrue, reason: 'label must close the URI: $raw');
  return Uri.decodeComponent(raw.substring(open + 1, raw.length - 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Names that stress URI encoding. Parentheses are covered separately
  // because the geo label deliberately rewrites them.
  const nastyNames = <String>[
    'Café & Co',
    'Pizza #1',
    '100% Pasta',
    'Fish+Chips',
    'a=b&c=d',
    'Sushi 🍣 Bar',
    '寿司 大',
    'Кафе «Центр»',
    'مطعم الشام',
    "L'Ami Louis",
    'Quote "Bar"',
    r'Slash/Back\slash',
    'Question? Mark',
    'Tab\tName',
    'ünï cödé ñ',
  ];

  group('apple URI', () {
    for (final name in nastyNames) {
      test('round-trips name "$name" through q', () {
        final uri = mapsUris(_named(name), apple: true).single;

        // Re-parse from the serialized string, as the OS would.
        final reparsed = Uri.parse(uri.toString());
        expect(reparsed.scheme, 'https');
        expect(reparsed.host, 'maps.apple.com');
        expect(reparsed.queryParameters['q'], name);
        expect(reparsed.queryParameters['ll'], '48.8566,2.3522');
        // Only the two documented keys: nothing leaked out of the name.
        expect(reparsed.queryParameters.keys.toSet(), {'ll', 'q'});
        expect(reparsed.fragment, isEmpty);
      });
    }

    test('negative coordinates keep their sign', () {
      final uri = mapsUris(
        _named('Bar', lat: -33.8688, lng: -151.2093),
        apple: true,
      ).single;

      expect(uri.queryParameters['ll'], '-33.8688,-151.2093');
    });

    test('whitespace-only name still yields a valid URI with ll', () {
      final uri = mapsUris(_named('   '), apple: true).single;

      expect(uri.queryParameters['ll'], '48.8566,2.3522');
      expect(Uri.parse(uri.toString()).host, 'maps.apple.com');
    });

    test('very long (1500 char) name stays parseable and intact', () {
      final name = 'Long ' * 300;
      final uri = mapsUris(_named(name), apple: true).single;

      expect(Uri.parse(uri.toString()).queryParameters['q'], name.trim());
    });
  });

  group('android geo URI', () {
    for (final name in nastyNames) {
      test('round-trips name "$name" through the label', () {
        final geo = mapsUris(_named(name), apple: false).first;

        expect(geo.scheme, 'geo');
        expect(_geoLabel(geo), name.trim());
        // Reserved characters must not appear raw inside the label, or the
        // maps app would see extra query params / a fragment.
        final label = geo.toString().substring(
          geo.toString().indexOf('(') + 1,
          geo.toString().length - 1,
        );
        for (final reserved in ['&', '#', ' ', '?', '"', '<', '>']) {
          expect(label.contains(reserved), isFalse, reason: 'raw "$reserved"');
        }
      });
    }

    test('coordinates appear both as the geo target and the q anchor', () {
      final geo = mapsUris(_named('Bar'), apple: false).first.toString();

      expect(geo, startsWith('geo:48.8566,2.3522?q=48.8566,2.3522('));
    });

    test('parentheses are rewritten so the label cannot be closed early', () {
      final geo = mapsUris(_named('Le Bar (Paris) (2)'), apple: false).first;
      final raw = geo.toString();

      // Exactly one "(" and one ")" in the whole URI: the label delimiters.
      expect('('.allMatches(raw), hasLength(1));
      expect(')'.allMatches(raw), hasLength(1));
    });

    test('a name that is only parentheses degrades to an empty label', () {
      final geo = mapsUris(_named('()'), apple: false).first;

      expect(geo.toString(), 'geo:48.8566,2.3522?q=48.8566,2.3522()');
    });

    test('negative coordinates keep their sign in geo and web fallback', () {
      final uris = mapsUris(
        _named('Bar', lat: -33.8688, lng: -151.2093),
        apple: false,
      );

      expect(uris.first.toString(), startsWith('geo:-33.8688,-151.2093?q='));
      expect(uris.last.queryParameters['query'], '-33.8688,-151.2093');
    });

    test('web fallback is https google maps search with api=1', () {
      final web = mapsUris(_named('Bar'), apple: false).last;

      expect(web.scheme, 'https');
      expect(web.host, 'www.google.com');
      expect(web.path, '/maps/search/');
      expect(web.queryParameters['api'], '1');
      // The fallback intentionally carries no name (coordinates only).
      expect(web.toString(), isNot(contains('Bar')));
    });
  });

  group('default launcher (url_launcher method channel faked)', () {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    late List<String> launched;

    setUp(() {
      launched = [];
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    void fakeChannel(Future<Object?> Function(String url) onLaunch) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method != 'launch') return null;
            final url =
                (call.arguments as Map<Object?, Object?>)['url']! as String;
            launched.add(url);
            return await onLaunch(url);
          });
    }

    Future<bool> run(TargetPlatform platform, Restaurant restaurant) async {
      debugDefaultTargetPlatformOverride = platform;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      try {
        return await container.read(mapsLauncherProvider)(restaurant);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    test('iOS launches exactly one https://maps.apple.com URL', () async {
      fakeChannel((_) async => true);

      final ok = await run(TargetPlatform.iOS, _named('Cafe Central'));

      expect(ok, isTrue);
      expect(launched, hasLength(1));
      expect(launched.single, startsWith('https://maps.apple.com/?'));
    });

    test('macOS uses Apple Maps too', () async {
      fakeChannel((_) async => true);

      await run(TargetPlatform.macOS, _named('Cafe Central'));

      expect(launched.single, startsWith('https://maps.apple.com/?'));
    });

    test('Android launches the geo: URI first and stops on success', () async {
      fakeChannel((_) async => true);

      final ok = await run(TargetPlatform.android, _named('Cafe Central'));

      expect(ok, isTrue);
      expect(launched, hasLength(1));
      expect(launched.single, startsWith('geo:48.8566,2.3522?q='));
    });

    test('Android: geo returns false (no handler) -> web fallback', () async {
      fakeChannel((url) async => !url.startsWith('geo:'));

      final ok = await run(TargetPlatform.android, _named('Cafe Central'));

      expect(ok, isTrue);
      expect(launched, hasLength(2));
      expect(launched.last, startsWith('https://www.google.com/maps/search/'));
    });

    test('Android: geo throws -> web fallback still tried', () async {
      fakeChannel((url) async {
        if (url.startsWith('geo:')) {
          throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
        }
        return true;
      });

      final ok = await run(TargetPlatform.android, _named('Cafe Central'));

      expect(ok, isTrue);
      expect(launched, hasLength(2));
    });

    test('every candidate failing resolves false and never throws', () async {
      fakeChannel((_) async => false);
      expect(await run(TargetPlatform.android, _named('X')), isFalse);
      expect(launched, hasLength(2));

      launched.clear();
      fakeChannel((_) async => throw PlatformException(code: 'boom'));
      expect(await run(TargetPlatform.android, _named('X')), isFalse);
      expect(await run(TargetPlatform.iOS, _named('X')), isFalse);
    });
  });
}
