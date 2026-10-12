## [P2] Report and Block still await the server acknowledgement: offline, the report sheet spins and the chat is not left after blocking (leftover of the closed offline-writes bug)

**Repro:**
1. Open a chat or a meal, enable airplane mode.
2. Report the other person (pick a reason, Submit) or Block them (confirm).

**Expected:** (universal edge case 2) the write is queued and the UI moves on within a few seconds, like chat/create-meal/request/rating since `settleOrQueue`.
**Actual:** `closed/2026-10-09-awaited-writes-block-ui-offline.md` fixed four call sites. `ReportController.submit` and `BlockController.block` still `await` the repository write directly. Firestore only completes it on server ack, so: the report sheet stays on its in-flight spinner with the fields disabled; blocking never reaches `onBlocked` (`context.go('/chats')`), so the user stays in the chat with the person they just blocked (the chat disappears from the list once the local snapshot updates, but the screen does not leave), and the `user_blocked`/`user_reported` events are not sent until reconnect. Same for unblock, profile save (`updateProfile`) and the age-gate batch. Safety actions are the ones people take on a bad connection.

**Verified by test:** `test/features/safety/application/offline_safety_writes_edge_test.dart` (harness case passes; the two offline cases are skipped until fixed).

**Device/OS:** controller tests with a never-completing repository future; real airplane-mode behaviour NOT VERIFIED.
**Build:** develop @ 979e5f2
**Frequency:** always while offline.

**Hypothesis / fix:** wrap `report(...)` and `block(...)` in `settleOrQueue(...)` exactly like the other controllers (rejections inside 3 s still surface); consider the same for `ProfileController` saves.
