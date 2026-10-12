## [P2] Discover is empty for any device that reports a position outside Paris (store reviewers, travellers, emulator default location) although v1 is "Paris-only by location fallback"

**Repro:**
1. Run on a device/emulator whose location is not in Île-de-France (an Apple/Google reviewer in California, Mountain View emulator default, a user in Lyon) and grant location.
2. Open Discover while Paris meals exist (e.g. the stage seed data).

**Expected:** PRD: "v1 is Paris-only, enforced by defaulting location fallback to Paris center, not by hard geo-gating" - the feed shows the Paris meals (and the in-app notice explains v1 is Paris-only).
**Actual:** `LocationService.currentOrParis` only falls back to Paris when permission is denied or the fix fails. A real position elsewhere is used as is; `discoveryControllerProvider` queries the geohash cell of that position (precision 3), so none of the Paris meals match: "No meals near you yet". The reviewer can create a meal (Paris restaurants only) but never sees another meal, so request / approve / chat cannot be evaluated: a plausible App Store 2.1 / Play "app incomplete" rejection. Also affects a Paris resident's friend visiting from abroad.

**Verified by test:** `test/features/meal/application/discovery_outside_paris_edge_test.dart`: a device in Paris queries `u09` (passes); San Francisco queries `9q8`, New York `dr5` (skipped until fixed).

**Device/OS:** controller-level test; real GPS behaviour NOT VERIFIED.
**Build:** develop @ 979e5f2
**Frequency:** always for non-Paris locations.

**Hypothesis:** in `currentOrParis` (or in the discovery controller) clamp: if the position is farther than ~100 km from Paris centre (or outside the `u09` cell), use `parisCenter`. Also give App Review a demo path in the review notes (`docs/STORE_METADATA.md`) and seed meals in the production database before submission.
