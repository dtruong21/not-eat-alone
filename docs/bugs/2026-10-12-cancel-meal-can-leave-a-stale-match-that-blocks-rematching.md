## [P3] `cancelMatchedMeal` (guest withdraw) and `deleteAccount` (guest) reopen the meal first and delete the match afterwards, non-atomically: a crash in between leaves a meal that can never be matched again

**Repro (rules emulator, `firebase/rules-test/client_write_shapes.rules.test.cjs` "a failed deleteMatchTree after the meal reopened blocks every future approval of that meal"):**
1. A meal is matched (meal `matched`, `requests/m_g` approved, `matches/m` exists).
2. `applyCancel` as the guest commits its transaction (meal `open`, `guestId: null`, request deleted) and the function dies / times out before `deleteMatchTree` runs (it is a separate, later step; so is the chat deletion in `deleteAccount` after `releaseMatchedMeals`).
3. Another guest requests the (now open, listed) meal; the host taps Approve.

**Expected:** The meal can be approved again.
**Actual:** The approve transaction must create `matches/{mealId}`, which still exists; `matches` has `allow update: if false`, so the transaction is PERMISSION_DENIED and the host always sees "Couldn't approve this request". Retrying the callable is not possible (the meal is no longer `matched`: `failed-precondition`), the old guest still has a chat they can read, and reminders for the reopened meal would not match. `deleteAccount` is retryable (the cascade finds the match through `participants`), the callable is not.

**Verified:** rules emulator test above (passes = the deadlock exists); the happy path of `applyCancel`, `releaseMatchedMeals`, both reminder functions and a double-cancel race are green against the Firestore emulator (`firebase/functions/test-emulator/state_machine.test.cjs`).

**Device/OS:** Firestore emulator, compiled functions.
**Build:** develop @ 979e5f2
**Frequency:** only when the function is interrupted in that window (rare).

**Hypothesis / fix:** delete the match tree inside the same transaction for the doc itself (`txn.delete(matches/{id})`; messages/reads best-effort afterwards), or let the callable also accept `status == 'open'` + an existing match for the caller and finish the cleanup (idempotent), or relax the `matches` create rule to allow create over an existing doc whose meal is open.
