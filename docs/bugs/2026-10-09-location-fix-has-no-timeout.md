## [P2] Discovery can spin forever: `LocationService.currentOrParis` has no timeout when permission is granted but no GPS fix arrives

**Repro:**
1. Grant location permission, then open the app where no fix is available (indoors with weak signal, emulator without a mock location, flaky Play Services).
2. Open Discover.

**Expected:** The doc comment says "Paris centre on any denial/error/timeout"; the feed should fall back to Paris within a few seconds (v1 is Paris-only).
**Actual:** `Geolocator.getCurrentPosition()` is called with no `timeLimit` and default (best) accuracy, so `locationProvider` stays `AsyncLoading`; `discoveryControllerProvider` returns `Stream.empty()` while it loads, so the feed shows the spinner indefinitely (pull-to-refresh re-awaits the same hang). Only denial and thrown errors fall back. Unit test: a never-completing `getPosition` never resolves.

**Device/OS:** unit test; real GPS-less behaviour NOT VERIFIED (no device).
**Build:** develop @ 8cf1b41
**Frequency:** whenever no fix arrives (environment dependent).

**Hypothesis:** `getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 5)))` (city-level is enough for a geohash cell) and/or `.timeout(const Duration(seconds: 8), onTimeout: () => throw TimeoutException(...))` so the existing catch returns `parisCenter`. Android manifest only declares `ACCESS_COARSE_LOCATION`, which is consistent with low accuracy.

**Regression test:** `test/core/location/location_service_timeout_edge_test.dart` ("a position that never arrives resolves to Paris within 30s", skipped until fixed).
