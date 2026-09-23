/// Analytics client — the only place the analytics SDK is touched.
///
/// Widgets and providers call `track()` / `identify()` / `reset()` from here.
/// Provider: Firebase Analytics (`firebase_analytics`). Calls are routed
/// through an injectable sink so this file is unit-testable without the
/// plugin, and every send is guarded so a failed call NEVER throws — the
/// ~11 controllers that call `track()` inside `AsyncValue.guard` rely on
/// this to keep a failed analytics send from failing a successful write.
library;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'package:not_eat_alone/core/analytics/events.dart';

/// A sink that logs a named event with scalar params. The default
/// implementation forwards to Firebase Analytics; tests override it via
/// [debugSetLogSink].
typedef LogEvent = Future<void> Function(
  String name,
  Map<String, Object?> params,
);

Future<void> _defaultLogSink(String name, Map<String, Object?> params) {
  // Firebase Analytics parameter values must be String or num — drop nulls
  // and cast the rest (our typed events only ever emit scalars).
  final cleaned = <String, Object>{
    for (final entry in params.entries)
      if (entry.value != null) entry.key: entry.value!,
  };
  return FirebaseAnalytics.instance.logEvent(name: name, parameters: cleaned);
}

Future<void> _defaultSetUserId(String? uid) =>
    FirebaseAnalytics.instance.setUserId(id: uid);

Future<void> _defaultSetUserProperty(String name, String? value) =>
    FirebaseAnalytics.instance.setUserProperty(name: name, value: value);

LogEvent _logSink = _defaultLogSink;
Future<void> Function(String? uid) _setUserIdSink = _defaultSetUserId;
Future<void> Function(String name, String? value) _setUserPropertySink =
    _defaultSetUserProperty;

/// Overrides the event-log sink. Test-only.
@visibleForTesting
void debugSetLogSink(LogEvent sink) => _logSink = sink;

/// Overrides the `setUserId` sink. Test-only.
@visibleForTesting
void debugSetUserIdSink(Future<void> Function(String? uid) sink) =>
    _setUserIdSink = sink;

/// Overrides the `setUserProperty` sink. Test-only.
@visibleForTesting
void debugSetUserPropertySink(
  Future<void> Function(String name, String? value) sink,
) =>
    _setUserPropertySink = sink;

bool _forceSend = false;

/// Bypasses [_shouldDropInDev] so tests can exercise the sink without
/// needing `ANALYTICS_IN_DEV`. Test-only.
@visibleForTesting
void debugSetForceSend(bool value) => _forceSend = value;

/// Resets every test seam to its production default. Call from `tearDown`.
@visibleForTesting
void debugResetAnalytics() {
  _logSink = _defaultLogSink;
  _setUserIdSink = _defaultSetUserId;
  _setUserPropertySink = _defaultSetUserProperty;
  _forceSend = false;
}

/// When true, analytics fires even in debug builds. Default false keeps the
/// prod event stream clean. Flip via dart-define for local QA:
///
///   flutter run --dart-define=ANALYTICS_IN_DEV=true
const _analyticsInDev = bool.fromEnvironment('ANALYTICS_IN_DEV');

bool get _shouldDropInDev =>
    !_forceSend && kDebugMode && !_analyticsInDev;

// ─── Public API ──────────────────────────────────────────────────────────────

/// Fire a typed event. The event must extend `AppEvent` — anything else fails
/// to compile.
///
/// Never throws: a failed send is swallowed (and logged via `debugPrint`) so
/// callers inside `AsyncValue.guard` are always safe.
Future<void> track(AppEvent event) async {
  if (_shouldDropInDev) {
    debugPrint('[analytics:dev] ${event.name} ${event.props}');
    return;
  }

  try {
    await _logSink(event.name, event.props);
  } catch (e) {
    debugPrint('[analytics] track failed: $e');
  }
}

/// Associate subsequent events with a user. Call on sign-up + sign-in.
/// `uid` is the Firebase Auth uid — never an email or name.
///
/// Never throws — see [track].
Future<void> identify(String uid, [UserProperties? properties]) async {
  if (_shouldDropInDev) {
    debugPrint('[analytics:dev] identify $uid ${properties?.toMap()}');
    return;
  }

  try {
    await _setUserIdSink(uid);
    final props = properties?.toMap() ?? const <String, Object?>{};
    for (final entry in props.entries) {
      if (entry.value == null) continue;
      await _setUserPropertySink(entry.key, entry.value.toString());
    }
  } catch (e) {
    debugPrint('[analytics] identify failed: $e');
  }
}

/// Disassociate the current device from a user. Call on sign-out.
/// Without this, subsequent anonymous events incorrectly attribute to the
/// prior user.
///
/// Never throws — see [track].
Future<void> reset() async {
  if (_shouldDropInDev) {
    debugPrint('[analytics:dev] reset');
    return;
  }

  try {
    await _setUserIdSink(null);
  } catch (e) {
    debugPrint('[analytics] reset failed: $e');
  }
}
