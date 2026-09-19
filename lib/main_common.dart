import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/routing/router.dart';

Future<void> bootstrap({
  required FlavorConfig config,
  required FirebaseOptions options,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.current = config;
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env is optional at boot; keys are wired later.
  }
  await Firebase.initializeApp(options: options);
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
    return MaterialApp.router(
      title: FlavorConfig.current.appTitle,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      routerConfig: router,
    );
  }
}
