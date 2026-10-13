/// Boots the real app (`NotEatAloneApp`, via `bootstrap`) against the
/// Firebase Emulator Suite for `integration_test/` scenarios.
///
/// TEST CODE ONLY — must never be imported from `lib/`.
library;

import 'package:flutter/widgets.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/config/emulator_config.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/firebase/options/firebase_options_prod.dart';
import 'package:not_eat_alone/core/locale/locale_controller.dart';
import 'package:not_eat_alone/main_common.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The flavor E2E tests boot under. Must be [Flavor.prod] — its
/// `firestoreDatabaseId` is `'(default)'`, the only database id the
/// Firestore emulator serves (`Flavor.stage`'s `'stage'` database id is
/// not seeded/served by the emulator).
FlavorConfig testFlavor() => FlavorConfig(flavor: Flavor.prod);

/// Boots the app under [tester] against the local Firebase Emulator Suite
/// (see `EmulatorConfig.local()`) using the prod Firebase options (the
/// emulators ignore the real project's keys but `bootstrap` still needs a
/// valid `FirebaseOptions` to call `Firebase.initializeApp`), then settles
/// the first frame.
Future<void> pumpApp(WidgetTester tester) async {
  // E2E finders are English: pin the language so a French simulator, or a
  // Français tapped in an earlier run, cannot change what the app shows.
  await (await SharedPreferences.getInstance()).setString(localePrefsKey, 'en');
  await bootstrap(
    config: testFlavor(),
    options: DefaultFirebaseOptions.currentPlatform,
    emulator: const EmulatorConfig.local(),
  );
  await tester.pumpAndSettle();
}

/// Renders only on the authed Discover screen, whatever the feed state: the
/// "Create a meal" FAB, or, for an empty feed (where the FAB is hidden), the
/// empty state's own "Create a meal" button.
Finder discoverFeedMarker() => find.byWidgetPredicate(
  (widget) =>
      widget.key == const Key('discovery_create_meal_button') ||
      widget.key == const Key('discovery_empty_create_button'),
  description: 'the Discover screen marker (FAB or empty-state button)',
);
