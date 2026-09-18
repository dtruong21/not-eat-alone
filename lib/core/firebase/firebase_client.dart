/// Firebase initialization + top-level accessors.
///
/// Setup (run once per project):
///
///   1. Install the FlutterFire CLI:
///        dart pub global activate flutterfire_cli
///
///   2. From the project root, run:
///        flutterfire configure
///
///      This generates `lib/firebase_options.dart` (COMMITTED — see gotcha #2
///      in the master spec; the web API key is not secret, App Check + rules
///      are the security model).
///
///   3. In `lib/main.dart`, before `runApp`:
///
///        import 'package:firebase_core/firebase_core.dart';
///        import 'firebase_options.dart';
///
///        Future<void> main() async {
///          WidgetsFlutterBinding.ensureInitialized();
///          await Firebase.initializeApp(
///            options: DefaultFirebaseOptions.currentPlatform,
///          );
///          runApp(const ProviderScope(child: App()));
///        }
///
/// Repositories in this folder consume `db` / `auth` via these getters — they
/// don't take a `FirebaseFirestore` argument so they're trivial to instantiate
/// from a Riverpod provider. For tests, override the provider with a mock
/// repository; don't try to mock these getters.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:not_eat_alone/core/config/flavor.dart';

/// The Firestore instance for the active flavor. Single Firebase project,
/// split databases: prod reads `(default)`, stage reads the named `stage`
/// database — see [FlavorConfig.firestoreDatabaseId]. Use only inside
/// `lib/core/firebase/`.
FirebaseFirestore get db => FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: FlavorConfig.current.firestoreDatabaseId,
    );

/// The default Auth instance. Use only inside `lib/core/firebase/` and the
/// auth feature.
FirebaseAuth get auth => FirebaseAuth.instance;
