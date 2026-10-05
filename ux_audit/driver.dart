/// Host-side driver for `flutter drive` (see the `ux-capture` Makefile target).
///
/// `flutter test <file> -d <device>` only runs on a device for files under
/// `integration_test/` (flutter_tools matches that directory prefix), and this
/// capture harness deliberately lives outside it so `make e2e` never picks it
/// up. `flutter drive --driver ux_audit/driver.dart --target
/// ux_audit/capture_test.dart` runs the same `IntegrationTestWidgetsFlutter
/// Binding` test on the simulator instead.
///
/// DEV TOOLING ONLY.
library;

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
