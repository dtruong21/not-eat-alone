/// Reproduces the "last listener unmounts while an action is in flight"
/// lifecycle that crashed `@riverpod` (autoDispose) action controllers with
/// `UnmountedRefException` (found live in the E2E request flow: Firestore
/// latency compensation swaps the "Request to join" button — the controller's
/// only watcher — for "Requested" before the write resolves).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

/// Starts [action] with one listener attached, removes that listener while
/// the action is still awaiting (the caller holds its dependency open until
/// [release] is called), pumps so autoDispose can run, re-attaches a fresh
/// listener, then releases the action and awaits it.
///
/// Returns every state the re-attached listener saw (first entry is the
/// state at re-attach time, via `fireImmediately`). A controller that keeps
/// itself alive while in flight is still `loading` at re-attach and then
/// lands its final data/error on that same instance. One that doesn't is
/// disposed, and its trailing `state =` throws out of the awaited action.
Future<List<AsyncValue<T>>> runWithListenerRemovedMidFlight<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider, {
  required Future<void> Function() action,
  required void Function() release,
}) async {
  final first = container.listen(provider, (_, _) {});
  final inFlight = action();
  first.close();
  await container.pump();

  final seen = <AsyncValue<T>>[];
  final second = container.listen(
    provider,
    (_, next) => seen.add(next),
    fireImmediately: true,
  );
  release();
  try {
    await inFlight;
  } finally {
    second.close();
  }
  return seen;
}
