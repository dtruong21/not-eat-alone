## [P2] Returning users see the sign-in screen (cold start) and the 18+ age gate (every sign-in on a new phone) while the session / user document is still loading

**Repro:**
1. Signed-in, onboarded user force-kills the app and relaunches (auth session still resolving), or signs in on a phone that has no cached copy of their `users/{uid}` / `profiles/{uid}`.
2. Watch the first screens.

**Expected:** A neutral splash/loading state until the auth session and the user's own document have resolved; no screen that asks the user to do something they have already done.
**Actual:** The `redirect` reads `authStateProvider.value != null` and `currentUserDocProvider.value?.ageVerified ?? false`, i.e. `loading` is treated as "signed out" / "not age-verified". So: auth still resolving -> `/auth/signin`; signed in but the user doc still loading (always the case for the first sign-in on a device, on slow networks for seconds, and the doc needs two server reads: `users` + `profiles`) -> `/onboarding/age` (the router comment documents this as intended). Then the gate flips and the user is bounced to `/discover`. The age gate is interactive: a returning user can enter a date of birth during the flash; the rules then reject it (dob is locked once verified) and an error is shown.

**Verified by test:** `test/core/routing/cold_start_gate_flash_edge_test.dart` (skipped until fixed): harness case lands on `/discover`; with a pending user-doc stream the location is `/onboarding/age`; with a pending auth stream it is `/auth/signin`. Real timing NOT VERIFIED (no device).

**Device/OS:** go_router 18.0.1 widget-test router; iOS and Android.
**Build:** develop @ 979e5f2
**Frequency:** always on cold start (sign-in screen, ~100-300 ms) and on new-device sign-in (age gate, until the docs arrive).

**Hypothesis:** `authRedirect` takes a `loading` flag (auth or user doc resolving): while true, redirect to a `/splash` route (or return `null` and render a loading scaffold above the shell) and only apply the gates once both providers have a value. `refreshListenable` already fires when they resolve.
