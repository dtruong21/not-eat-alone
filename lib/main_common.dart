import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:not_eat_alone/core/analytics/analytics_listener.dart';
import 'package:not_eat_alone/core/config/emulator_config.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/design/font_license.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/routing/router.dart';

Future<void> bootstrap({
  required FlavorConfig config,
  required FirebaseOptions options,
  EmulatorConfig? emulator,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.current = config;
  registerFontLicense();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env is optional at boot; keys are wired later.
  }
  await Firebase.initializeApp(options: options);

  if (emulator != null) {
    final e = emulator;
    FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: config.firestoreDatabaseId,
    ).useFirestoreEmulator(e.host, e.firestorePort);
    await FirebaseAuth.instance.useAuthEmulator(e.host, e.authPort);
    FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).useFunctionsEmulator(e.host, e.functionsPort);
    await FirebaseStorage.instance.useStorageEmulator(e.host, e.storagePort);
  } else {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider:
          kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  try {
    await GoogleSignIn.instance.initialize();
  } catch (_) {
    // Google provider not yet configured in Firebase; sign-in surfaces the
    // error later.
  }
  runApp(const ProviderScope(child: NotEatAloneApp()));
}

class NotEatAloneApp extends ConsumerWidget {
  const NotEatAloneApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return AnalyticsListener(
      child: MaterialApp.router(
        title: FlavorConfig.current.appTitle,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        routerConfig: router,
      ),
    );
  }
}
