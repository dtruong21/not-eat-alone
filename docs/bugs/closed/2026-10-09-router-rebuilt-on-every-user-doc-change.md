## [P1] Any change to the signed-in user's own doc rebuilds the GoRouter and throws the user back to /discover

**Repro:**
1. Sign in as a fully onboarded user and open any screen above the shell (Settings, a chat at `/chats/:matchId`, the rating sheet host screen), or stay on the Profile tab.
2. Cause the `users/{uid}` doc to change while the screen is open. Real triggers: (a) the other participant rates you and `onRatingCreated` rewrites `ratingSum/ratingCount/ratingAvg`; (b) you add or remove a profile photo (`ProfileController.addPhoto/removePhoto` write `photoUrls` immediately, before "Save"); (c) you save the profile; (d) `createdAt` serverTimestamp resolving after first sign-up.
3. Watch the screen.

**Expected:** The user stays where they are; navigation state is independent of profile field values.
**Actual:** `routerProvider` (`lib/core/routing/router.dart` ~L102-106) does `ref.watch(currentUserDocProvider).value` and builds a brand-new `GoRouter` whenever the doc emits a different `AppUser`. `MaterialApp.router` receives a new `routerConfig`, which restarts at `initialLocation: '/discover'`. Consequences: a user in a chat is yanked to Discover when a rating lands; in profile setup/edit every photo add resets the screen (typed name/bio in an un-saved form are lost on setup, the edit tab jumps to Discover); the old `GoRouter` is never disposed.

**Evidence (automated, not on a device):** `test/core/routing/router_stability_test.dart`
- "router instance is stable when only ratingAvg/ratingCount change" - router identity changes (skipped, un-skip when fixed).
- "a user-doc change does not navigate away from /settings" - full `routerProvider` + `MaterialApp.router`: after the doc changes the Settings screen is replaced by the Discover shell (skipped, un-skip when fixed).
- "a rebuilt GoRouter sends the user back to initialLocation" - framework characterisation (passing).

**Device/OS:** flutter_test widget harness (Flutter 3.47.4, Linux host). Not reproduced on iOS/Android hardware.
**Build:** develop @ 8cf1b41
**Frequency:** always on any change to a field of the user doc.

**Hypothesis:** Make the router long-lived: build one `GoRouter` and feed auth/profile state through `refreshListenable` (or `ref.listen` + `router.refresh()`), or at minimum `ref.watch(currentUserDocProvider.select((a) => (a.value?.ageVerified, a.value?.profileComplete)))` so only gate-relevant changes rebuild it. Also `ref.onDispose(router.dispose)`.

**Workaround:** none for the user (they must navigate back). Photo add on profile setup: add photos before typing the name.

**Status:** Fixed — `routerProvider` now builds one long-lived `GoRouter`; `refreshListenable` re-runs `redirect` only when signed-in / age-verified / profile-complete change, and `redirect` reads current state. Stability tests un-skipped; gate-change redirect tests added (`test/core/routing/router_stability_test.dart`).
