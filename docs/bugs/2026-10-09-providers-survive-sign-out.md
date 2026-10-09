## [P2] Per-user providers and Firestore listeners are never disposed or reset on sign-out; chat list opens one full-history listener per match

**Repro:**
1. Sign in as A, open a few chats / profiles (creates `userDocProvider(uid)`, `chatMessagesProvider(matchId)`, `otherReadProvider`, `requestMealProvider`, `matchMealProvider`, `myRatingProvider` entries).
2. Sign out (Settings) and sign in again as A or B without killing the process.
3. Open the same profile/chat.

**Expected:** (universal "Auth" + "Memory" items) Sign-out drops local state; every `.snapshots()` listener is owned by an auto-disposing provider.
**Actual:** All of these are plain `StreamProvider.family` / `FutureProvider.family` (Riverpod 3: not auto-dispose, and none watches `authStateProvider`), so (a) after sign-out the backend terminates the listener with permission-denied and the cached `AsyncError`/stale data survives into the next session (test: a second `userDocProvider('x')` subscription is never created after sign-out then sign-in), (b) listeners accumulate for the life of the process (TEST-PLAN: "No Firestore listener leaks"), (c) `ChatListTile` watches `chatMessagesProvider(match.id)` for every row only to show the last message, so the Chats tab opens one listener per match that downloads that match's entire message history (reads and memory grow with chat length; messages have no `limit`), (d) `requestMealProvider` and `matchMealProvider` cache the first fetch forever (known follow-up (4) in the plan).

**Device/OS:** provider-level test (`test/core/auth_transition_state_test.dart`); memory growth not measured (no DevTools).
**Build:** develop @ 8cf1b41
**Frequency:** always.

**Hypothesis:** Use `.autoDispose` on the family providers (screens keep them alive while mounted) and make auth-dependent ones `ref.watch(authStateProvider.select((a) => a.value?.uid))`; show the last message from a `limit(1)` query (or denormalise `lastMessage`/`lastMessageAt` on the match via the message trigger) and page the thread with `limit(50)` + load-more.

**Regression test:** `auth_transition_state_test.dart` "sign-out then sign-in re-subscribes per-user streams" (skipped until fixed).
