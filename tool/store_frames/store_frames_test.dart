// Composes the framed store screenshots (caption + rounded, shadowed capture
// on a token-coloured canvas). See tool/store_frames/README.md.
//
//   fvm flutter test tool/store_frames/store_frames_test.dart \
//     --dart-define=STORE_WRITE=true
//
// Without STORE_WRITE the test only renders in memory and checks sizes,
// contrast and caption fit. It skips when the raw captures are absent.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/tokens.dart';

import 'captions.dart';
import 'png_rgb.dart';

const _write = bool.fromEnvironment('STORE_WRITE');
const String _srcEn = String.fromEnvironment(
  'STORE_SRC_EN',
  defaultValue: 'ux_audit/out/20-light-default',
);
const String _srcFr = String.fromEnvironment(
  'STORE_SRC_FR',
  defaultValue: 'ux_audit/out/20-fr-light-default',
);

/// (output slug, raw capture name) in store order.
const _shots = <(String, String)>[
  ('01_discover', '22_discover_data'),
  ('02_meal_detail', '40_meal_detail_open'),
  ('03_requests', '52_requests_data'),
  ('04_chat', '63_chat_messages'),
  ('05_safety', '76_chat_safety_sheet'),
];

const Color _background = WarmPlayfulColorsLight.accent;
const Color _ink = WarmPlayfulColorsLight.text;

/// A store canvas: pixel size and where things sit on it.
class _Spec {
  const _Spec(
    this.dir,
    this.width,
    this.height, {
    required this.margin,
    required this.captionTop,
    required this.fontSize,
    required this.phoneTop,
    required this.phoneWidth,
  });
  final String dir;
  final int width;
  final int height;
  final double margin;
  final double captionTop;
  final double fontSize;
  final double phoneTop;
  final double phoneWidth;
}

const _specs = <_Spec>[
  _Spec(
    'ios-6.9',
    1290,
    2796,
    margin: 90,
    captionTop: 120,
    fontSize: 96,
    phoneTop: 420,
    phoneWidth: 1070,
  ),
  _Spec(
    'play-phone',
    1080,
    1920,
    margin: 80,
    captionTop: 90,
    fontSize: 76,
    phoneTop: 330,
    phoneWidth: 700,
  ),
];

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

TextStyle _captionStyle(double size) => TextStyle(
  fontFamily: 'Nunito',
  fontWeight: FontWeight.w800,
  fontSize: size,
  height: 1.15,
  color: _ink,
);

Widget _frame(_Spec s, String caption, ui.Image shot) {
  final phoneHeight = s.phoneWidth * shot.height / shot.width;
  // Token radius scaled from logical (402 pt wide) to canvas pixels.
  final radius = WarmPlayfulRadius.xl * s.phoneWidth / 402;
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: _background,
      child: Stack(
        children: [
          Positioned(
            top: s.captionTop,
            left: s.margin,
            right: s.margin,
            child: Text(
              caption,
              textAlign: TextAlign.center,
              style: _captionStyle(s.fontSize),
            ),
          ),
          Positioned(
            top: s.phoneTop,
            left: (s.width - s.phoneWidth) / 2,
            width: s.phoneWidth,
            height: phoneHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: WarmPlayfulColorsLight.shadow,
                    blurRadius: s.phoneWidth * 0.06,
                    offset: Offset(0, s.phoneWidth * 0.02),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: RawImage(
                  image: shot,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String? _skipReason(String dir) {
  if (!Directory(dir).existsSync()) return 'source folder missing: $dir';
  for (final (_, src) in _shots) {
    if (!File('$dir/$src.png').existsSync()) return 'missing $dir/$src.png';
  }
  return null;
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Nunito')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Nunito-ExtraBold.ttf').readAsBytesSync(),
          ),
        ),
      );
    await loader.load();
  });

  test('caption ink has >= 4.5:1 contrast on the canvas', () {
    expect(_contrast(_ink, _background), greaterThanOrEqualTo(4.5));
  });

  for (final (locale, dir) in [('en', _srcEn), ('fr', _srcFr)]) {
    final skip = _skipReason(dir);
    testWidgets(
      'store frames $locale${skip == null ? '' : ' (skipped: $skip)'}',
      (tester) async {
        // flutter_test draws shadows hard by default; the store art wants blur.
        debugDisableShadows = false;
        try {
          for (final spec in _specs) {
            for (var i = 0; i < _shots.length; i++) {
              final (slug, src) = _shots[i];
              final caption = storeCaptions[locale]![i];

              // Caption fits: one painted line per explicit line, none wrapped.
              final painter = TextPainter(
                text: TextSpan(
                  text: caption,
                  style: _captionStyle(spec.fontSize),
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: spec.width - 2 * spec.margin);
              expect(
                painter.computeLineMetrics().length,
                caption.split('\n').length,
                reason: '$locale/$slug caption wraps beyond its explicit lines',
              );
              expect(caption.split('\n').length, lessThanOrEqualTo(2));

              tester.view
                ..physicalSize = Size(
                  spec.width.toDouble(),
                  spec.height.toDouble(),
                )
                ..devicePixelRatio = 1;
              addTearDown(tester.view.reset);

              final bytes = File('$dir/$src.png').readAsBytesSync();
              late ui.Image shot;
              late Uint8List png;
              await tester.runAsync(() async {
                final codec = await ui.instantiateImageCodec(bytes);
                shot = (await codec.getNextFrame()).image;
              });
              // The whole phone stays on the canvas (nothing interactive cut).
              expect(
                spec.phoneTop + spec.phoneWidth * shot.height / shot.width,
                lessThanOrEqualTo(spec.height),
              );
              final key = GlobalKey();
              await tester.pumpWidget(
                RepaintBoundary(
                  key: key,
                  child: SizedBox(
                    width: spec.width.toDouble(),
                    height: spec.height.toDouble(),
                    child: _frame(spec, caption, shot),
                  ),
                ),
              );
              await tester.runAsync(() async {
                final boundary =
                    key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final img = await boundary.toImage();
                expect(img.width, spec.width);
                expect(img.height, spec.height);
                final rgba = (await img.toByteData())!.buffer.asUint8List();
                // Canvas is opaque: every pixel's alpha must be 255.
                for (var a = 3; a < rgba.length; a += 4) {
                  if (rgba[a] != 255) {
                    fail('translucent pixel in $locale/$slug');
                  }
                }
                png = encodeRgbPng(rgba, img.width, img.height);
              });
              if (_write) {
                File('docs/store/screenshots/$locale/${spec.dir}/$slug.png')
                  ..createSync(recursive: true)
                  ..writeAsBytesSync(png);
              }
            }
          }
        } finally {
          debugDisableShadows = true;
        }
      },
      skip: skip != null,
    );
  }
}
