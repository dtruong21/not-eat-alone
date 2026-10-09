import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registers the bundled Nunito files so layout tests measure real glyph
/// widths. Without this `flutter test` renders every string in the Ahem test
/// font (1em per glyph), which makes overflow and wrap results meaningless
/// for text-scale / small-screen checks.
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final loader = FontLoader('Nunito');
  for (final f in const ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
    final bytes = await File('assets/fonts/Nunito-$f.ttf').readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}
