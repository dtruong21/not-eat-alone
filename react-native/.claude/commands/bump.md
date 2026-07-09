---
description: Bump version + build number based on CHANGELOG [Unreleased] (release hat)
argument-hint: [patch | minor | major] — optional override
---

Bump the project version per `docs/VERSIONING.md`. Argument is an optional override; without it the bump is inferred from `CHANGELOG.md [Unreleased]`.

Steps:

1. **Read `CHANGELOG.md`.** Find the `## [Unreleased]` section.
2. **Check for content.** If `[Unreleased]` has no entries under any sub-heading (only empty headings or whitespace), STOP with this exact error and do nothing else:
   `Nothing to release. Add an entry to CHANGELOG.md [Unreleased] first.`
3. **Decide the bump type:**
   - If `$ARGUMENTS` is `major`, `minor`, or `patch` → use it as override (skip inference).
   - Else infer:
     - Any entries under `### Added` → `minor`
     - Else any under `### Changed` (without "(BREAKING)" annotation) or `### Fixed` or `### Security` → `patch`
     - Else any under `### Removed` or `### Changed` with "(BREAKING)" → `major`
     - Else (entries exist but only in `### Deprecated`) → `minor`
4. **Read current version** from `app.json`:
   - `expo.version` (e.g. `"0.2.3"`)
   - `expo.ios.buildNumber` (e.g. `"14"`)
   - `expo.android.versionCode` (e.g. `14`)
5. **Compute new version:**
   - `major`: `(X+1).0.0`
   - `minor`: `X.(Y+1).0`
   - `patch`: `X.Y.(Z+1)`
6. **Compute new build:** `max(ios.buildNumber, android.versionCode) + 1`. Set both to this — keep them in sync.
7. **Update `app.json`** with the three new values. Preserve all other fields exactly.
8. **Update `CHANGELOG.md`:**
   - Rename `## [Unreleased]` → `## [<new-version>] — <YYYY-MM-DD>` (use today's date; if you don't know it, ask).
   - Insert a fresh empty block at the top:
     ```
     ## [Unreleased]
     
     ### Added
     
     ### Changed
     
     ### Fixed
     
     ```
9. **Output (exactly this format):**
   ```
   Bumped: <old-version> → <new-version> (build <old-build> → <new-build>)
   Type: <patch|minor|major> (<reason>)
   Next: git tag v<new-version>-<channel> && git push origin v<new-version>-<channel>
   ```

Constraints:
- Do NOT execute `git tag` or `git push`. That's the user's call (or `/release`'s).
- Do NOT change anything outside `app.json` and `CHANGELOG.md`.
- If the override conflicts with the CHANGELOG (e.g. `major` requested but no breaking entries), do the override anyway but note "(override of inferred <type>)".

No code dumps, no diff dumps. The headline IS the artifact.
