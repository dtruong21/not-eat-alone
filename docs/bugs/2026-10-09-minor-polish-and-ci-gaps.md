## [P3] Small gaps found in the sweep (CI lint, foreground banner, token-refresh error, rate prompt timing, Apple/Android)

**Repro / Actual / Hypothesis (each independent):**
1. CI: the `functions-build` job runs `npm ci`, `build`, `test` but not `npm run lint` (lint is clean today, so it can regress silently). Add `- run: npm run lint`.
2. `PushListener._showForegroundBanner` shows a snackbar for every foreground push, even for a chat message while that very chat is open (duplicate of the visible bubble). Skip the banner when the current route is `/chats/{matchId}` of the payload.
3. `PushRepositoryImpl.registerToken` token-refresh handler uses `.catchError((e, st) { throw RepositoryWriteException(...) })`: the rethrow escapes as an unhandled async error, which `PlatformDispatcher.onError` reports to Crashlytics as fatal. Log and swallow (or retry).
4. `bootstrap` records every uncaught async error as `fatal: true` (`PlatformDispatcher.instance.onError`), skewing crash-free-user stats. Use `fatal: false` for non-framework errors.
5. `postMealReminder` pushes "How was it?" at the first hourly run after the meal START time (up to an hour after it began), not after the meal; the rating rule also opens at `dateTime`. Consider `dateTime + 2h`.
6. `ChatListTile` unread dot is "last message is inbound" and never clears after opening the chat (documented MVP simplification; will read as permanently unread).
7. `debugLogDiagnostics: true` is hard-coded in `routerProvider` (go_router uses `developer.log`, so it does not reach release logcat; still gate it with `kDebugMode`).
8. `AgeGateController`: an under-18 DOB signs the user out but nothing prevents an immediate retry with an adult DOB (neutral age gate is self-attested; consider a short device-level lockout if the stores ask).
9. `DiscoveryViewed` fires on every stream emission (see discovery bug).

**Device/OS:** code review; nothing here reproduced on hardware.
**Build:** develop @ 8cf1b41
**Frequency:** always.
