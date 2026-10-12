## [P2] The `requests` create rule has no key/type whitelist: one guest can break a host's whole request inbox

**Repro (rules emulator):**
1. As any signed-in guest, `setDoc(requests/{mealId}_{guestUid}, {id, mealId, guestId, hostId, status:'pending', createdAt: 'not-a-timestamp'})` on any open meal. Accepted: the rule checks ids/status/host/block/women-only but not the other keys or their types (unlike meals, messages, ratings and reports). Extra keys (100 KB junk) and a client-chosen `createdAt` (e.g. year 3000 to pin to the top of the inbox) are accepted too.
2. The host opens the request inbox.

**Expected:** The write is rejected, or the host still sees the valid requests.
**Actual:** `RequestRepositoryImpl._fromDoc` throws `RepositoryParseException(requests/...)` (`FormatException: Invalid date format`) for the bad document, so `watchPendingForHost` errors: the host sees "Something went wrong", the badge count falls to 0, and every other pending request of that host (all meals) is unreachable. The host cannot deny the poisoned request (no tile) and clients cannot delete it, so hosting is broken until an admin removes the document. One request is enough, from any account, against any host.

**Regression tests (skipped until fixed):** `test/features/matching/data/request_inbox_poison_edge_test.dart`; `firebase/rules-test/client_write_shapes.rules.test.cjs` ("requests: a guest cannot store a client-chosen createdAt or extra keys", node `skip`).

**Device/OS:** Firestore emulator + fake Firestore.
**Build:** develop @ 979e5f2
**Frequency:** always.

**Hypothesis / fix:** rules: `keys().hasOnly(['id','mealId','guestId','hostId','status','createdAt']) && createdAt == request.time && id == requestId && mealId is string` on create (the app writes exactly these, see `rules_write_shape_contract_test.dart`); client: drop unparseable docs in `watchPendingForHost` instead of failing the stream. Same class as `2026-10-12-one-malformed-meal-breaks-discover-for-everyone.md`.
