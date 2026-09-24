/// Boots the real app (`NotEatAloneApp`, via `bootstrap`) against the
/// Firebase Emulator Suite for `integration_test/` scenarios.
///
/// TEST CODE ONLY — must never be imported from `lib/`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/config/emulator_config.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/firebase/options/firebase_options_prod.dart';
import 'package:not_eat_alone/main_common.dart';

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
  await bootstrap(
    config: testFlavor(),
    options: DefaultFirebaseOptions.currentPlatform,
    emulator: const EmulatorConfig.local(),
  );
  await tester.pumpAndSettle();
}
