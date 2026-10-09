import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the bundled Nunito font's SIL OFL 1.1 text to Flutter's licence
/// registry so the app's Licences page lists it. Call once at boot.
void registerFontLicense({AssetBundle? bundle}) {
  LicenseRegistry.addLicense(() async* {
    final text = await (bundle ?? rootBundle).loadString(
      'assets/fonts/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(['Nunito'], text);
  });
}
