---
description: Cut a release build (release-engineer)
argument-hint: <staging | production>
---

Use the `release-engineer` agent to cut a release on channel: $ARGUMENTS

Run the pre-release checklist from the agent definition. STOP at the first failure and report it — do not proceed past a failed check.

If all checks pass:
1. Bump the `version:` field in `pubspec.yaml` using semver+build syntax (e.g. `1.2.0+15` — `+15` is the iOS/Android build number, must increase monotonically).
2. Update `CHANGELOG.md` with user-facing changes only.
3. Tag commit `v<version>-$ARGUMENTS` (e.g. `v1.2.0-staging`).
4. Print the exact commands to run — do not execute them. The user runs the cut. Include:
   - `git push origin v<version>-$ARGUMENTS` (pushing the tag triggers the matching Codemagic workflow in `codemagic.yaml`)
   - OR `codemagic-cli-tools` invocation: `codemagic-cli-tools workflows trigger --workflow-id <staging|production> --branch main`
   - `firebase deploy --only firestore:rules,firestore:indexes,functions` if `firebase/` changed in this release

Output: checklist results + the commands. Nothing else.
