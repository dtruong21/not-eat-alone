/// App flavor + per-flavor configuration.
///
/// Set once, in each flavor entrypoint (`main_stage.dart` / `main_prod.dart`),
/// before `runApp`: `FlavorConfig.current = FlavorConfig(flavor: Flavor.stage);`
///
/// Single Firebase project, split Firestore databases: prod uses the
/// `(default)` database, stage uses a named `stage` database. See
/// `lib/core/firebase/firebase_client.dart` for the accessor that reads
/// [firestoreDatabaseId].
library;

enum Flavor { stage, prod }

class FlavorConfig {
  FlavorConfig({required this.flavor});

  final Flavor flavor;

  /// Set once at boot by the active flavor entrypoint.
  static late FlavorConfig current;

  bool get isStage => flavor == Flavor.stage;

  String get appTitle => isStage ? 'Convyve (stage)' : 'Convyve';

  /// Firestore database id for this flavor — `'stage'` for the stage
  /// flavor, `'(default)'` for prod. Both live in the same Firebase project.
  String get firestoreDatabaseId => isStage ? 'stage' : '(default)';

  /// Root path segment in the SHARED Storage bucket, keeping stage and prod
  /// objects apart: `'stage'` for stage, `'prod'` for prod.
  String get storagePathPrefix => isStage ? 'stage' : 'prod';
}
