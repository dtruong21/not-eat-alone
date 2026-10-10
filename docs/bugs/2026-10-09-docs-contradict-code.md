## [P3] TEST-PLAN, PRD and privacy policy contradict the code in several places

**Repro:** compare the quoted lines with the code.

**Expected:** Docs describe shipped behaviour (the plan is the release gate; the privacy policy is a store requirement).
**Actual:**
1. TEST-PLAN Auth: "Non-owner cannot read/write another user's `users/{uid}` doc" - read is open to any signed-in user (see `2026-10-09-users-collection-exposes-dob-to-all-signed-in-users`).
2. TEST-PLAN Security: "No `cloud_firestore` imports outside `lib/core/firebase/`" - the architecture (CLAUDE.md) allows them in each feature's `data/` layer; the grep as written fails by design. Use `grep -rlE "package:(cloud_firestore|firebase_auth|google_sign_in|sign_in_with_apple)" lib | grep -v "/data/\|lib/core/firebase/\|main_common"` (currently clean).
3. TEST-PLAN Meal creation "Deferred: real Places search, fake 20-restaurant list" and Discovery "Request to join is present but disabled (Plan 6)" - both shipped.
4. TEST-PLAN Safety: account deletion "password confirmation -> success dialog" (code: one confirm dialog, no re-authentication, no success dialog, auto sign-out); "Known issues: deletion via callable only / Blaze / profile pictures deferred" (code deletes the Storage prefix and has a Settings button); deletion cascade list omits that `reports` the user authored or that target them are retained.
5. TEST-PLAN Ratings: "second attempt overwrites" (rules: create-only, update denied, verified Q2); "meal `status` flips to `completed` after both rate" (`postMealReminder` completes every matched meal at its first hourly run after `dateTime`, regardless of ratings); "nudge push shortly after rating" (it is sent after the meal start time, to both, before anyone rates, up to an hour after the meal began); Known issue "no deep-link for type `rate`" is stale (mapper handles it).
6. PRD Open questions (moderation mitigation): "18+ phone-verified accounts" - phone is optional; Google/Apple sign-in need no phone verification, and age is self-attested (owner may rewrite `dob`).
7. Privacy policy: lists meal "cuisine, allergies/dietary notes, photos, participant list" and "city, geohash" location (the app stores restaurant, note, women-only flag; the device location is read only to compute a query cell and is not stored); does not disclose that exact date of birth is readable by other signed-in users, nor retention of `reports`; no mention that restaurant search text is sent to Google Places via our function.
8. TRACKING-PLAN: Identification strategy (identify/reset) and user properties are not implemented (see analytics bug); `push_opened` examples list type `'match'`, actual types are `message|rate|request|request_update|meal_reminder`.
9. TEST-PLAN pre-release gate lists "in-app feedback submits"; there is no in-app feedback feature (template item - drop or build).
10. TEST-PLAN "Dark mode / Dynamic type" items cite `textScaleFactor`; the API is `textScaler`.

**Device/OS:** n/a (documentation).
**Build:** develop @ 8cf1b41
**Frequency:** always.

**Hypothesis:** Update the plan text in the same PR that fixes the matching code bug; prefer deleting stale "Deferred/Known issues" lines.
