import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

/// Runs once per test file: `bootstrap` initialises `intl` date data in the
/// app, so tests that build date-formatting widgets need it too.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting('en');
  await initializeDateFormatting('fr');
  await testMain();
}
