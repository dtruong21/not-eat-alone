---
description: Cut a release build (release-engineer)
argument-hint: <staging | production>
---

Use the `release-engineer` agent to cut a release on channel: $ARGUMENTS

Run the pre-release checklist from the agent definition. STOP at the first failure and report it — do not proceed past a failed check.

If all checks pass:
1. Run `/bump` to bump `version` + `iosBuildNumber` + `androidVersionCode` in `app.json` per `docs/VERSIONING.md`. (If `/bump` aborts because `CHANGELOG.md [Unreleased]` is empty, surface its error and stop — there's nothing to release.)
2. Verify `CHANGELOG.md` got promoted (`/bump` did this — the new versioned section is at the top, a fresh empty `[Unreleased]` block is in place).
3. Tag commit `v<version>-$ARGUMENTS`.
4. Print the exact commands to run (`eas build ...`, `eas submit ...`, `firebase deploy ...`) — do not execute them. The user runs the cut.

Output: checklist results + the new version + the commands. Nothing else.
