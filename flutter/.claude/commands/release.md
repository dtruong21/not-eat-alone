---
description: Cut a release build (release hat, main loop)
argument-hint: <staging | production>
---

Wear the **release hat** (`docs/PRINCIPLES.md § Role hats`). Cut a release on channel: $ARGUMENTS

Run the pre-release checklist in `docs/RELEASE.md` (incl. `flutter analyze` clean, `flutter test` + `flutter test integration_test` green, codegen produces no diff). STOP at the first failure and report it — do not proceed past a failed check.

If all checks pass:
1. Run `/bump` to bump the `version:` field in `pubspec.yaml` per `docs/VERSIONING.md`. (If `/bump` aborts because `CHANGELOG.md [Unreleased]` is empty, surface its error and stop — there's nothing to release.)
2. Verify `CHANGELOG.md` got promoted (new versioned section at top, fresh empty `[Unreleased]` block in place).
3. Tag commit `v<version>-$ARGUMENTS` (e.g. `v1.2.0-staging`).
4. Print the exact commands to run — do not execute them. The user runs the cut. Include:
   - `git push origin v<version>-$ARGUMENTS` (pushing the tag triggers the matching Codemagic workflow in `codemagic.yaml`)
   - `firebase deploy --only firestore:rules,firestore:indexes,functions` if `firebase/` changed in this release

Output: checklist results + the new version + the commands. Nothing else.
