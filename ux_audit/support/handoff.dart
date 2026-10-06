/// The ready/ack handshake between the capture test (running inside the iOS
/// Simulator) and the host script `tool/ux_capture.sh`.
///
/// A simulator process is not sandboxed from the host filesystem, so both
/// sides share [kHandoffDir]. The test writes `<name>.ready`; the host takes
/// `xcrun simctl io <device> screenshot` and writes `<name>.ack`; the test
/// then removes both files and carries on. Every wait is bounded.
///
/// DEV TOOLING ONLY — never imported from `lib/` or `integration_test/`.
library;

import 'dart:async';
import 'dart:io';

/// Directory shared with the host script (see `tool/ux_capture.sh`).
const String kHandoffDir = '/tmp/convyve-ux';

/// How long [shot] waits for the host's `.ack` before giving up.
const Duration kAckTimeout = Duration(seconds: 30);

/// Asks the host to photograph the simulator screen as `<name>.png`, then
/// blocks (bounded to [timeout]) until the host acknowledges.
///
/// Throws a [TimeoutException] if no `.ack` arrives, so a dead host script
/// fails the run loudly instead of silently producing no screenshots.
Future<void> shot(String name, {Duration timeout = kAckTimeout}) async {
  final dir = Directory(kHandoffDir)..createSync(recursive: true);
  final ready = File('${dir.path}/$name.ready');
  final ack = File('${dir.path}/$name.ack');
  if (ack.existsSync()) ack.deleteSync();
  ready.writeAsStringSync(DateTime.now().toIso8601String());
  final deadline = DateTime.now().add(timeout);
  try {
    while (!ack.existsSync()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('no host ack for "$name" within $timeout');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  } finally {
    if (ready.existsSync()) ready.deleteSync();
    if (ack.existsSync()) ack.deleteSync();
  }
}

int _commandCounter = 0;

/// Sends [command] to the host script and waits (bounded) for it to be done.
///
/// Supported by `tool/ux_capture.sh`: `freeze-firestore` / `thaw-firestore`
/// (SIGSTOP / SIGCONT of the Firestore emulator) and `freeze-auth` /
/// `thaw-auth` (the firebase-tools process that hosts the Auth emulator).
/// A frozen emulator never answers, so an action that waits on it stays "in
/// flight" (spinner showing) for as long as the host photographs the screen.
/// The host thaws on its own after 25 s and on exit.
Future<void> hostCommand(
  String command, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final dir = Directory(kHandoffDir)..createSync(recursive: true);
  final id = '${DateTime.now().millisecondsSinceEpoch}-${_commandCounter++}';
  final req = File('${dir.path}/cmd.$id.req');
  final ack = File('${dir.path}/cmd.$id.ack');
  req.writeAsStringSync(command);
  final deadline = DateTime.now().add(timeout);
  try {
    while (!ack.existsSync()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('no host ack for command "$command"');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  } finally {
    if (req.existsSync()) req.deleteSync();
    if (ack.existsSync()) ack.deleteSync();
  }
}
