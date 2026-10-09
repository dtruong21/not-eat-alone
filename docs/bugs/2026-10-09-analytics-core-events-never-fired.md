## [P2] `app_opened`, `signup_completed`, `signin_completed` are in the tracking plan and registry but never fired; `identify()`/user properties/`reset()` never called

**Repro:**
1. `grep -rn "AppOpened(\|SignupCompleted(\|SigninCompleted(" lib/` outside `lib/core/analytics/events.dart` returns nothing.
2. `grep -rn "identify(\|setUserProperty\|UserProperties(" lib/` shows no caller outside `lib/core/analytics/client.dart`.
3. Sign in on a device with `--dart-define=ANALYTICS_IN_DEV=true` and watch DebugView: no `signup_completed`, `signin_completed` or `app_opened`.

**Expected:** Every event in `docs/TRACKING-PLAN.md` that the metrics depend on fires: Activation rate uses `signup_completed`, Retention W1 uses `app_opened` + `signup_completed`; the plan's Identification strategy says call `identify(uid)` on sign-up and `reset()` on sign-out and set `signup_date`, `signup_method`, `app_version`, `platform`.
**Actual:** 3 of 28 events are dead, no user identity/properties are ever attached (so DebugView/BigQuery cohorts by signup method/app version are impossible), and sign-out does not reset. Doc/registry parity itself is fine (28/28, new test).

**Device/OS:** static analysis + unit test; DebugView not checked (no device).
**Build:** develop @ 8cf1b41
**Frequency:** always.

**Hypothesis:** Fire `AppOpened` from a `WidgetsBindingObserver` (resumed) in `app.dart`/`bootstrap`; fire `SignupCompleted`/`SigninCompleted` where `authStateProvider` first reports a user (new vs returning = whether `users/{uid}` exists) or in `AuthRepositoryImpl` callers; call `identify(uid)` there and `reset()` in both sign-out paths. If the events are intentionally cut, remove them from the plan and registry and redefine Activation/Retention on Firebase's automatic `first_open`/`session_start`.

**Regression test:** `test/core/analytics/tracking_plan_parity_test.dart` ("every registry event is fired from somewhere in lib/", skipped until fixed; the plan/registry parity tests pass).
