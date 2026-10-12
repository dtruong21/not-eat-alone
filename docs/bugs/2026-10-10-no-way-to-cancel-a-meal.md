## [P2] Nobody can cancel a meal or withdraw from a matched one

**Repro:**
1. Create a meal, or get matched on one.
2. Look for a way to cancel it (host) or withdraw (matched guest): there is none. The `meals` rules forbid client deletes, no cancel function exists, and `MealStatus.cancelled` is never written.

**Expected:** A host can cancel their own meal (open or matched) and a matched guest can withdraw; the other side is told. This is the main no-show lever for the Low-pressure pillar and is also how an abandoned `open` meal gets closed.
**Actual:** Meals stay `open`/`matched` until the time passes. Matched people who can't come can only message in chat.

**Hypothesis:** `cancelMeal` callable (host: open or matched; guest: withdraw back to `open`), notifies the other party, sets `status: cancelled`; scheduled cleanup of past `open` meals is optional (the discovery query no longer reads them). Needs a PRD entry first (`/spec`) and a design (`/design`: where the action lives, confirmation, states).

**Device/OS:** n/a (missing feature found in the QA sweep).
**Build:** develop
**Frequency:** always.

Split from `docs/bugs/closed/2026-10-09-discovery-feed-stale-and-unbounded.md`.
