## [P2] When the other person cancels / withdraws / deletes their account, an open or stale chat shows a generic error with a live composer, and `markRead` raises an uncaught error that Crashlytics records as fatal

**Repro:**
1. Host and guest are matched and both have the chat open (or the guest later taps a stale "You're in!" / meal-reminder push).
2. The other person uses "Can't make it" (or deletes their account): `cancelMatchedMeal` / `deleteAccount` delete `matches/{mealId}` and its `messages`/`reads`.

**Expected:** The chat says it is no longer available (and offers a way back); no errors are reported.
**Actual:** Every rule under `matches/{id}` does `get()` on the parent match, so with the match gone all reads/writes are PERMISSION_DENIED. The chat shows "Something went wrong - please try again." (retrying cannot help), the app bar falls back to a bare "Chat" with no actions, and the composer stays enabled (each send fails). `_ChatScreenState.initState` and the new-message listener call `ChatController.markRead` via `unawaited(...)` with no error handling, so the `RepositoryWriteException` is an uncaught async error; `bootstrap` reports every such error with `fatal: true`, so each open of a dead chat is counted as a crash and skews crash-free stats.

**Verified by test:** `test/features/chat/presentation/chat_screen_cancelled_match_edge_test.dart` (skipped until fixed): opening the chat of a deleted match throws the uncaught `RepositoryWriteException` and still renders the composer. Rules side: `firebase/rules-test/client_write_shapes.rules.test.cjs` (messages read on a deleted match is denied). Device behaviour NOT VERIFIED.

**Device/OS:** widget test; iOS and Android.
**Build:** develop @ 979e5f2
**Frequency:** always.

**Hypothesis:** catch in `markRead` (log, no rethrow), and in `ChatScreen` treat "match not in `chatListProvider` after it loaded" or a permission error as a "This chat is no longer available" state (hide composer and actions, button back to Chats). Related minor item: `matchMealProvider` is a one-shot read, so "Can't make it" stays visible after the other person already cancelled and then fails with the generic "Check your connection" message.
