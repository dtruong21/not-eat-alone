---
description: Cut a release build (release-engineer)
argument-hint: <staging | production>
---

Use the `release-engineer` agent to cut a release on channel: $ARGUMENTS

Run the pre-release checklist from the agent definition. STOP at the first failure and report it — do not proceed past a failed check.

If all checks pass:
1. Bump `version` + `iosBuildNumber` + `androidVersionCode` in `app.json`.
2. Update `CHANGELOG.md` with user-facing changes only.
3. Tag commit `v<version>-$ARGUMENTS`.
4. Print the exact commands to run (`eas build ...`, `eas submit ...`, `firebase deploy ...`) — do not execute them. The user runs the cut.

Output: checklist results + the commands. Nothing else.
