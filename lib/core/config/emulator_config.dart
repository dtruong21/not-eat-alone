/// Localhost Firebase Emulator Suite coordinates for E2E test boots.
///
/// Only ever passed to [bootstrap] from `integration_test/` — shipped
/// entrypoints (`main_stage.dart`/`main_prod.dart`) pass no emulator config,
/// so production builds never touch this.
library;

class EmulatorConfig {
  const EmulatorConfig({
    this.host = '127.0.0.1',
    this.authPort = 9099,
    this.firestorePort = 8080,
    this.functionsPort = 5001,
    this.storagePort = 9199,
  });

  /// Default localhost config (desktop / CI). Android emulators reach the
  /// host loopback via `10.0.2.2` — pass that as [host] there.
  const factory EmulatorConfig.local() = EmulatorConfig._local;

  const EmulatorConfig._local() : this();

  final String host;
  final int authPort;
  final int firestorePort;
  final int functionsPort;
  final int storagePort;
}
