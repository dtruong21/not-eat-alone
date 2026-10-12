## [P2] Offline, writes awaited by the UI never resolve: chat composer stuck on a spinner, Create meal / Request to join / Rate spin until reconnect

**Repro:**
1. Open a chat, enable airplane mode.
2. Type a message and tap send.
3. Observe the composer; try to send a second message.

**Expected:** (universal edge case 2) The write queues via Firestore offline persistence and the UI behaves optimistically: the draft clears, the message shows as pending in the thread, further messages can be queued.
**Actual:** Firestore completes a write's Future only on server acknowledgement. `ChatRepositoryImpl.sendMessage`, `MealRepositoryImpl.createMeal`, `RequestRepositoryImpl.createRequest`, `RatingRepositoryImpl.submit` all `await` it inside `AsyncValue.guard`, so the controller state stays `loading` indefinitely. In the composer the draft stays in the field (while the same text already appears in the thread from the local cache, so it looks sent twice if the user edits/retries), the send button is disabled with a spinner, and only one message can be queued. Create meal / Request to join / Rate show their in-flight spinner (and then a success snackbar + navigation) only after reconnect, possibly long after the user left the screen or after the 5-minute lead window passed. Approve is a transaction and fails fast (documented); Deny is a bare write and never errors (documented).

**Device/OS:** widget test with a never-completing repository future (`test/features/chat/presentation/widgets/message_composer_offline_edge_test.dart`); real airplane-mode behaviour NOT VERIFIED (no device).
**Build:** develop @ 8cf1b41
**Frequency:** always while offline.

**Hypothesis:** For writes that are safe to queue (messages, ratings), do not await the server ack: `unawaited(ref.set(...))` after local validation, clear the draft/close the sheet immediately, and surface failures from the stream's `snapshotsInSync`/metadata (`hasPendingWrites`) instead. For create meal / request, either do the same or detect connectivity and show "You're offline - it will be sent when you reconnect".

**Regression test:** `message_composer_offline_edge_test.dart` "offline (write never acknowledged): composer is free again" (skipped until fixed).

**Status:** Fixed — `settleOrQueue` (`lib/core/util/queued_write.dart`) in the chat, create-meal, request and rating controllers: a write acknowledged or rejected within 3 s behaves as before (errors still surface); one still pending after 3 s counts as queued (Firestore offline persistence delivers it on reconnect) and the UI moves on. A rejection that only arrives after reconnect is logged. Real airplane-mode behaviour still to verify on a device.
