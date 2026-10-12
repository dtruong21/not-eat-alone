/// Lets the UI move on from a Firestore write that can't be acknowledged yet.
///
/// A Firestore write's `Future` completes only when the SERVER acknowledges it,
/// so offline it stays pending until reconnect — and a controller that awaits
/// it leaves its screen on a spinner for as long as the network is down. The
/// write itself is already queued by Firestore's offline persistence (and
/// visible in local snapshots), so after a short grace period we stop waiting.
///
/// Normal (online) behaviour is unchanged: a write acknowledged within
/// [grace] resolves, and one REJECTED within [grace] (rules, validation)
/// still throws so the caller can show its error state. A rejection that only
/// arrives later (after the UI moved on) is logged, because the screen is gone.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// How long to wait for the server before treating the write as queued.
const queuedWriteGrace = Duration(seconds: 3);

/// Awaits [write] for up to [grace]; completes normally on acknowledgement or
/// when the grace period ends with the write still pending (queued); throws if
/// the write fails within [grace].
Future<void> settleOrQueue(
  Future<void> write, {
  Duration grace = queuedWriteGrace,
}) {
  final settled = Completer<void>();
  final timer = Timer(grace, () {
    if (!settled.isCompleted) settled.complete();
  });

  write.then<void>(
    (_) {
      timer.cancel();
      if (!settled.isCompleted) settled.complete();
    },
    onError: (Object error, StackTrace stack) {
      timer.cancel();
      if (!settled.isCompleted) {
        settled.completeError(error, stack);
      } else {
        // The caller already moved on (offline); nobody can show this error.
        debugPrint('[queued write] failed after it was queued: $error');
      }
    },
  );

  return settled.future;
}
