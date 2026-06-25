---
description: Cut a release build (release-engineer)
argument-hint: <staging | production>
---

Use the `release-engineer` agent to cut a release on channel: $ARGUMENTS

Run the pre-release checklist from the agent definition. STOP at the first failure and report it — do not proceed past a failed check.

If all checks pass:
1. Run `/bump` to bump the `version:` field in `pubspec.yaml` per `docs/VERSIONING.md`. (If `/bump` aborts because `CHANGELOG.md [Unreleased]` is empty, surface its error and stop — there's nothing to release.)
2. Verify `CHANGELOG.md` got promoted (`/bump` did this — new versioned section at top, fresh empty `[Unreleased]` block in place).
3. Tag commit `v<version>-$ARGUMENTS` (e.g. `v1.2.0-staging`).
4. Print the exact commands to run — do not execute them. The user runs the cut. Include:
   - `git push origin v<version>-$ARGUMENTS` (pushing the tag triggers the matching Codemagic workflow in `codemagic.yaml`)
   - OR `codemagic-cli-tools` invocation: `codemagic-cli-tools workflows trigger --workflow-id <staging|production> --branch main`
   - `firebase deploy --only firestore:rules,firestore:indexes,functions` if `firebase/` changed in this release

Output: checklist results + the new version + the commands. Nothing else.
