## [P2] When a matched guest deletes their account the host's meal stays `matched` forever and the host still gets reminders for a meal with no match

**Repro:**
1. Host H creates a meal; guest G requests; H approves (meal `matched`, `matches/{mealId}` created).
2. G deletes their account (`deleteAccount`).
3. Inspect the data and wait for the reminder windows.

**Expected:** (cascade completeness) The host's meal returns to a joinable/cancelled state or the host is told; no reminders for a meal that has nobody coming.
**Actual:** `deleteAccount` deletes G's matches (and messages), requests and G's own meals, but H's meal doc keeps `status: 'matched'`, `guestId: G`. Result: the meal never reappears in Discover, the client cannot reopen it (rules deny `matched -> open`, verified live M10), `mealReminder` sends H "Your meal is tomorrow / coming up" (T-24h and T-2h) with a push that deep-links to `/chats/{mealId}`, where the match no longer exists (empty "Say hi" screen; sending fails the `matches` get in the message rule), and `postMealReminder` later asks H to rate a ghost. Mirror case: when the HOST deletes, the guest's matched chat silently disappears with no notification.

**Device/OS:** code + live emulator evidence for the rules (no deletion run end-to-end).
**Build:** develop @ 8cf1b41
**Frequency:** always for matched meals at deletion time.

**Hypothesis:** In `delete_account.ts`, before deleting matches, query `meals where guestId == uid and status == 'matched'` and set them to `open` (clear `guestId`, clear `reminder24hSent/reminder2hSent/postMealNotified`) if still in the future, else `cancelled`; send the host a push ("Your match left Convyve"). Add the `cancelled` check to `mealReminder` (already filtered by `status == matched`). Add the case to `test/deletion_plan.test.ts`. Also add the missing guest-side notification for host deletion.
