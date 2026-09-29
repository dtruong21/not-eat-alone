/// Firebase Emulator Suite admin helpers — clearing state between tests and
/// bounded polling for eventually-consistent reads (Cloud Functions
/// triggers, etc.).
///
/// TEST CODE ONLY: this file talks to `localhost` emulator admin endpoints
/// directly via `package:http`. It must never be imported from `lib/`.
library;

import 'dart:async';
import 'dart:io' show SocketException;

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
///
/// Each DELETE is retried (see [_deleteWithRetry]) on transient emulator
/// failures. Root cause of the one that motivated this: `firebase emulators:
/// exec` keeps ONE Firestore emulator alive across every test file, but each
/// file runs as its own app process that is killed at the end while still
/// holding Firestore listen streams. The next file's first clear commits the
/// deletes, then tries to notify those dead streams
/// (`CloudFirestoreV1ListenStream.notifyTargetRemove`), which throws
/// "call already cancelled" and surfaces as HTTP 499. The dead stream is
/// dropped by that failed attempt, so an immediate retry succeeds.
Future<void> clearEmulators() async {
  await _deleteWithRetry(
    Uri.parse(
      'http://$kEmulatorHost:8080/emulator/v1/projects/$kProjectId/'
      'databases/(default)/documents',
    ),
    'clearEmulators (Firestore)',
  );
  await _deleteWithRetry(
    Uri.parse(
      'http://$kEmulatorHost:9099/emulator/v1/projects/$kProjectId/accounts',
    ),
    'clearEmulators (Auth)',
  );
}

/// Maximum attempts per emulator admin DELETE (first try + retries).
const int _kMaxAttempts = 5;

/// Sends `DELETE [uri]`, retrying up to [_kMaxAttempts] times with
/// exponential backoff (250ms doubling, capped at 2s) on transient failures
/// only: HTTP 499 (emulator gRPC "call already cancelled"), any 5xx, and
/// connection errors ([SocketException]/[http.ClientException]). Any other
/// non-2xx (e.g. a 4xx from a wrong project id) is NOT retried. After the
/// last attempt the failure is thrown loudly via [_checkOk] (or rethrown for
/// connection errors) with the attempt count in the message.
Future<void> _deleteWithRetry(Uri uri, String what) async {
  var delay = const Duration(milliseconds: 250);
  for (var attempt = 1;; attempt++) {
    http.Response? res;
    Object? connectionError;
    try {
      res = await http.delete(uri);
    } on SocketException catch (e) {
      connectionError = e;
    } on http.ClientException catch (e) {
      connectionError = e;
    }

    final transient = connectionError != null ||
        (res != null && (res.statusCode == 499 || res.statusCode >= 500));
    if (res != null && !transient) {
      _checkOk(res, what, attempts: attempt);
      return;
    }
    if (attempt >= _kMaxAttempts) {
      if (res != null) _checkOk(res, what, attempts: attempt);
      throw StateError(
        '$what failed after $attempt attempts: $connectionError',
      );
    }
    await Future<void>.delayed(delay);
    final doubled = delay * 2;
    delay = doubled > const Duration(seconds: 2)
        ? const Duration(seconds: 2)
        : doubled;
  }
}

/// Throws a clear [StateError] (status + truncated body + attempt count) when
/// [res] isn't a 2xx — so a not-yet-booted emulator or a wrong project id/port
/// fails loudly here instead of surfacing as an opaque downstream
/// `FormatException` from a later `jsonDecode` of an HTML error page.
void _checkOk(http.Response res, String what, {int attempts = 1}) {
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw StateError('$what failed after $attempts attempt(s): '
        'HTTP ${res.statusCode} ${_truncate(res.body)}');
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
