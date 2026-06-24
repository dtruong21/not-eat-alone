---
description: Implement a feature (mobile-engineer)
argument-hint: <feature name from PRD>
---

Use the `mobile-engineer` agent to implement: $ARGUMENTS

Pre-flight (stop and ask if any fail):
- PRD entry exists in `docs/PRD.md` for this feature.
- Design spec exists in `docs/DESIGN.md` if a UI is involved.

Build order (strict):
1. Firestore wrapper in `lib/firebase/<collection>.ts` (typed + zod-validated)
2. Feature hook in `features/<name>/hooks/use<Name>.ts` (TanStack Query)
3. Component(s) in `features/<name>/components/`
4. Route in `app/`
5. Analytics events via `/track` for any user moment that maps to a metric in `docs/TRACKING-PLAN.md`

Constraints:
- No `any`. No direct Firestore SDK calls from components. No magic numbers — use tokens.
- No direct analytics SDK calls — always `track()` from `lib/analytics/client.ts`.
- Test the happy path on iOS + Android sim before declaring done.
- After done, hand off to `qa-engineer` via `/test <feature>`.
- Output: file diffs only. No restating the spec, no walkthrough of the code unless asked.
