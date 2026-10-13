import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Languages the app ships in. English is the fallback.
const supportedAppLocales = [Locale('en'), Locale('fr')];

/// `SharedPreferences` key holding the chosen language code.
const localePrefsKey = 'app_locale';

/// Reads the persisted language (null = follow the device). Called before
/// `runApp` so the first frame is already in the right language.
Future<Locale?> readSavedLocale() async {
  try {
    final code = (await SharedPreferences.getInstance()).getString(
      localePrefsKey,
    );
    for (final l in supportedAppLocales) {
      if (l.languageCode == code) return l;
    }
  } on Object {
    // Unreadable storage must never block startup: follow the device.
  }
  return null;
}

/// The locale read at bootstrap; overridden in `bootstrap`, null elsewhere.
final localeSeedProvider = Provider<Locale?>((ref) => null);

/// The user's language choice; null follows the device language.
final localeControllerProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

/// Holds and persists the chosen [Locale].
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() => ref.read(localeSeedProvider);

  /// Switches language now (null = follow the device) and remembers it.
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(localePrefsKey);
      } else {
        await prefs.setString(localePrefsKey, locale.languageCode);
      }
    } on Object {
      // The choice still applies for this session. The picker calls this
      // unawaited, so a failed write must not surface as an unhandled error.
    }
  }
}
