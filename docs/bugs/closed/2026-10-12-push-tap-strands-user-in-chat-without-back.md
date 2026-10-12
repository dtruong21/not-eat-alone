## [P1] Tapping a chat push replaces the whole navigation stack: the chat opens with no back button (iOS: no way out except killing the app)

**Repro:**
1. Signed in and onboarded, app in background or killed. The other person sends a chat message (push `type: message`), or a "You're in!" / meal-reminder / "How was it?" push arrives (all map to `/chats/{mealId}`).
2. Tap the notification.

**Expected:** The chat opens on top of the app (Chats tab underneath), with the AppBar back arrow, like opening it from the Chats tab, the meal detail banner or the inbox tile (all use `push`).
**Actual:** `pushNavigateProvider` calls `router.go('/chats/{id}')`. `/chats/:matchId` is a top-level route outside the `StatefulShellRoute`, so `go` replaces the stack with that single page: no `BackButton`, no bottom navigation, and the shell (which hosts `PushListener`) is disposed, so later push taps and foreground banners are ignored until the shell is rebuilt. iOS has no system back: the user can only leave through the "Can't make it" or block actions, or by killing the app. Android system back closes the app instead of returning to the app. Push taps for `message`, `rate`, `meal_reminder` and approved `request_update` are all affected (`/requests` and `/discover` are shell routes and fine).

**Verified by test:** `test/core/routing/push_tap_back_stack_edge_test.dart`. The baseline case (`push('/chats/m1')`) shows the shell underneath and a `BackButton`; the case that does what `PushListener` does (`pushNavigateProvider('/chats/m1')`) ends at stack depth 1 with no `BackButton` (skipped until fixed). Real-device behaviour NOT VERIFIED (no device), but go_router's `go` semantics make the failure deterministic.

**Device/OS:** go_router 18.0.1, widget-test router; applies to iOS and Android.
**Build:** develop @ 979e5f2
**Frequency:** always.

**Hypothesis / fix (small, in `lib/core/notifications/push_listener.dart`):** for destinations outside the shell, first `go` to the matching tab root (`/chats`) and then `push` the chat, e.g. `router.go('/chats'); router.push(location);` (check the two calls sequence in the stack-depth test; `/requests` and `/discover` stay a plain `go`). Cold start: do the same after the shell is mounted. The `push_listener_test.dart` spy tests keep working because they override `pushNavigateProvider`.

**Status:** Fixed — `pushNavigateProvider` lands on `/chats` then pushes `/chats/:id`, so the chat has a back arrow and the shell stays alive. Test: `push_tap_back_stack_edge_test.dart` (un-skipped).
