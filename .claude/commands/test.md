---
description: Write tests + run edge-case sweep for a feature (qa-engineer)
argument-hint: <feature name>
---

Use the `qa-engineer` agent for: $ARGUMENTS

Do:
1. Write Jest + RTL tests covering: happy path, empty state, error state.
2. Run the relevant edge cases from the agent's checklist (timezone, offline, DST, midnight rollover, large data, auth transitions, permissions denied — pick the ones that touch this feature).
3. Add new feature-specific edge cases to `docs/TEST-PLAN.md` under this feature's section.
4. **Verify analytics events fire.** For every event this feature added to `docs/TRACKING-PLAN.md`, trigger the user moment in the dev build and confirm the event arrives in the analytics debug view. File a bug if any don't.
5. File any bugs found as `docs/bugs/<YYYY-MM-DD>-<slug>.md` using the standard template.

Output:
- Test file paths created
- Test plan section updated (Y/N)
- Bug file paths created (if any) with severity
- One-line verdict: SHIP / BLOCK

No code dumps. No test summaries — the file IS the artifact.
