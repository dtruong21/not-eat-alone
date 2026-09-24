/// Firebase Emulator Suite admin helpers — clearing state between tests and
/// bounded polling for eventually-consistent reads (Cloud Functions
/// triggers, etc.).
///
/// TEST CODE ONLY: this file talks to `localhost` emulator admin endpoints
/// directly via `package:http`. It must never be imported from `lib/`.
library;

import 'dart:async';

import 'package:http/http.dart' as http;

/// The Firebase project id the emulators are configured for (see
/// `firebase.json` / `.firebaserc`) — used to build emulator REST paths.
const String kProjectId = 'not-eat-alone';

/// Host the Firebase Emulator Suite listens on for these tests. Desktop/CI
/// runs reach it via loopback; an Android emulator would need `10.0.2.2`
/// instead (not wired here — this harness targets desktop/CI runs).
const String kEmulatorHost = '127.0.0.1';

/// Deletes all Firestore documents and all Auth accounts in the running
/// emulators for [kProjectId], via the emulators' admin REST endpoints.
/// Call between tests (or in `setUp`) to start from a clean slate.
Future<void> clearEmulators() async {
  final firestoreRes = await http.delete(
    Uri.parse(
      'http://$kEmulatorHost:8080/emulator/v1/projects/$kProjectId/'
      'databases/(default)/documents',
    ),
  );
  _checkOk(firestoreRes, 'clearEmulators (Firestore)');
  final authRes = await http.delete(
    Uri.parse(
      'http://$kEmulatorHost:9099/emulator/v1/projects/$kProjectId/accounts',
    ),
  );
  _checkOk(authRes, 'clearEmulators (Auth)');
}

/// Throws a clear [StateError] (status + truncated body) when [res] isn't a
/// 2xx — so a not-yet-booted emulator or a wrong project id/port fails
/// loudly here instead of surfacing as an opaque downstream
/// `FormatException` from a later `jsonDecode` of an HTML error page.
void _checkOk(http.Response res, String what) {
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw StateError('$what failed: HTTP ${res.statusCode} '
        '${_truncate(res.body)}');
  }
}

/// Truncates [body] for inclusion in an exception message so a large HTML/
/// JSON error page doesn't flood test output.
String _truncate(String body, {int maxLength = 500}) =>
    body.length <= maxLength ? body : '${body.substring(0, maxLength)}...';

/// Polls [probe] on [interval] until it returns a non-null value, then
/// returns that value. Throws a [TimeoutException] if [timeout] elapses
/// first. Use to wait on eventually-consistent state (e.g. a Cloud Function
/// trigger writing a derived doc) without a fixed `Future.delayed`.
Future<T> pollUntil<T>(
  Future<T?> Function() probe, {
  Duration timeout = const Duration(seconds: 10),
  Duration interval = const Duration(milliseconds: 200),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final v = await probe();
    if (v != null) return v;
    await Future<void>.delayed(interval);
  }
  throw TimeoutException('pollUntil exceeded $timeout');
}
