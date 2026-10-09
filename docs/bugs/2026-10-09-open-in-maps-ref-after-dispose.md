## [P2] "Open in Maps" reads `ref` after `await track()` with no `mounted` check — unhandled error if the user leaves the screen in that window

**Repro:**
1. Open any meal's detail screen (restaurant with valid lat/lng).
2. Tap "Open in Maps" and leave the screen (back swipe / pop) before the awaited `analytics.track(const DirectionsOpened())` completes (slow Firebase Analytics platform-channel call, e.g. cold plugin, busy main isolate).
3. When `track()` resolves, `_open` continues to `ref.read(mapsLauncherProvider)`.

**Expected:** Nothing visible happens (or the launch still proceeds); no unhandled error.
**Actual:** `ref` is a getter on a defunct `ConsumerState`; it throws ("This widget has been unmounted, so the State no longer has a context" in debug; a null/state error in release). The error escapes the `onPressed` future as an unhandled async error (zone / `PlatformDispatcher.onError`, Crashlytics noise) and the maps hand-off is silently skipped. The `mounted` guard only protects the snackbar *after* the launcher call, not the `ref.read` before it.

**Device/OS:** flutter_test widget harness (Flutter 3.47.4, Linux host). NOT reproduced on a device/simulator (none available in this environment); timing window is milliseconds in practice, hence P2 not P1.
**Build:** develop @ 5fafd77
**Frequency:** always when the screen is disposed during the `track()` await (deterministic in the test with a gated log sink); rare for real users.

**Hypothesis:** In `_OpenInMapsButtonState._open` (`lib/features/meal/presentation/meal_detail_screen.dart` ~L606-620) capture the launcher before the first await (`final launch = ref.read(mapsLauncherProvider);`) and/or fire `track()` without awaiting it (`unawaited`), so the hand-off does not wait on analytics at all (also removes the dependency of the user-visible action on a telemetry call). Keep the `mounted` check before touching `context`.

**Regression test:** `test/features/meal/presentation/meal_detail_open_in_maps_edge_test.dart` -> "leaving the screen while the analytics send is in flight" (currently `skip: true`; un-skip when fixed).
