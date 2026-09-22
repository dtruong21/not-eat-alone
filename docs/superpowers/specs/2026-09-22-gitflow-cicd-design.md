# Convyve — Gitflow + CI/CD Design

**Date:** 2026-09-22
**Status:** Approved (design)
**Feature:** A full-gitflow branching model plus a complete GitHub Actions CI/CD pipeline (CI gate on every PR; automated Firebase backend deploy on integration/release). Store/build-signing is documented but deferred. Enabled by the repo going public (free GitHub Actions minutes, including macOS runners).

---

## 1. Goal & constraints

Give the project a real branching model and an automated pipeline now that CI is unblocked (public repo). Every PR runs a fast quality gate; merges to the integration and production branches auto-deploy the Firebase backend. No new external service — everything runs on GitHub Actions. App-store submission and code-signing are out of scope for this pass (no signing certs / App Store Connect / Play Console yet) but the pipeline is written so adding them later is a documented, additive step.

Single Firebase project (`not-eat-alone`, per `.firebaserc`: default/prod/stage all point to it). The stage/prod split lives in the **app flavor** (which Firestore database the app reads, which FCM registration), not in separate backend deploys — a Firestore rules/index or Storage deploy is shared across both databases. There is therefore one backend deploy target, not two.

## 2. Branching model (full gitflow)

| Branch | Role | Off | Merges to | Protected |
|---|---|---|---|---|
| `main` | Production. Every merge is a release. | — | — | ✅ |
| `develop` | Integration; maps to the **stage** environment. | main | — | ✅ |
| `feature/<slug>` | One feature/task. | develop | develop (PR) | — |
| `release/X.Y.Z` | Version freeze + stabilize before a prod release. | develop | main (PR) **and** back-merge to develop | — |
| `hotfix/X.Y.Z` | Urgent production fix. | main | main (PR) **and** back-merge to develop | — |

Rules of the model:
- `main` accepts merges only from `release/*` and `hotfix/*`. Feature work never targets `main` directly.
- Cutting a release: branch `release/X.Y.Z` off `develop`, bump the version in `pubspec.yaml` (`X.Y.Z+build`), fix only release blockers, PR to `main`. After merge, tag `vX.Y.Z` on `main` and back-merge `main` into `develop` so the version bump and any release fixes return to integration.
- Hotfix: branch `hotfix/X.Y.Z` off `main`, fix, bump patch version, PR to `main`, tag, back-merge to `develop`.
- Tags are `vX.Y.Z` on `main` only; each tag corresponds to a GitHub Release.

Branch protection (via `gh api`) on `main` and `develop`:
- Require a pull request before merging (no direct pushes).
- Require the CI status checks to pass before merge.
- Require branches to be up to date before merge.
- No force-pushes, no deletions.
- (Solo project: admin-enforcement left off so the owner can bypass in an emergency; approvals required = 0 since there is one maintainer. Documented as an intentional choice, easy to tighten when a collaborator joins.)

## 3. CI — `.github/workflows/ci.yml`

Triggers: `pull_request` targeting `main`, `develop`, `release/**`, `hotfix/**`; and `push` to `develop` and `main` (so the post-merge commit is verified before deploy). `concurrency` per ref with `cancel-in-progress: true`.

Jobs (all pin Flutter 3.47.4 via `subosito/flutter-action`, matching `.fvmrc`; pub cache enabled):

1. **analyze-test** (`ubuntu-latest`): `flutter pub get` → `dart run build_runner build --delete-conflicting-outputs` → `flutter analyze --no-fatal-infos` → `flutter test`. This is the existing gate, kept.
2. **build-android** (`ubuntu-latest`): pub get + codegen, then `flutter build apk --flavor stage -t lib/main_stage.dart --debug`. Compile/flavor-verification only; no signing. Committed `google-services.json` supplies Firebase config.
3. **build-ios** (`macos-latest`, free on public repos): pub get + codegen, then `flutter build ios --flavor stage -t lib/main_stage.dart --debug --no-codesign`. Verifies iOS + CocoaPods + the flavor compile without any certificates. Committed `GoogleService-Info.plist` supplies config.

The three jobs are the required status checks for branch protection. Codegen runs in each job because generated files (`*.freezed.dart`, `*.g.dart`) are git-ignored.

## 4. CD — `.github/workflows/deploy.yml`

Triggers: `push` to `develop` and `main` (after a PR merges). `concurrency` group `deploy-<ref>` so overlapping pushes serialize.

One job, **deploy-firebase** (`ubuntu-latest`):
- Guard: `if: ${{ secrets.FIREBASE_SERVICE_ACCOUNT != '' }}` is not directly expressible on a job-level secret condition, so the job checks the secret in a first step and exits early (success, with a notice) when it is absent — the pipeline is green before the user adds the secret, and live once they do.
- Auth: write `$FIREBASE_SERVICE_ACCOUNT` to a file, export `GOOGLE_APPLICATION_CREDENTIALS`.
- Deploy: `firebase deploy --only firestore,storage --project not-eat-alone --non-interactive` via `npx firebase-tools`. **Functions are excluded** (the `firebase/functions/` source directory does not exist yet — deploying it would fail on the `npm run build` predeploy). When Plan 8 adds Cloud Functions, extend the `--only` list to `firestore,storage,functions`.
- Because the project is single and the rules files are shared, this one deploy keeps both the `(default)` and `stage` databases current. Running it on both `develop` and `main` is intentional: `develop` is the integration deploy, `main` re-asserts the same rules at release time (idempotent).

Release step, only on `main` pushes that carry a tag: a second job **github-release** (`if: startsWith(github.ref, 'refs/tags/')` won't fire on a branch push, so instead it runs on `push` tags `v*` — see below) creates a GitHub Release. To keep tag-based releases clean, the release logic lives in its own trigger: `deploy.yml` also listens on `push: tags: ['v*']` and, on a tag, runs `softprops/action-gh-release` to publish release notes from the tag. (Tags are only ever on `main` per the model.)

Required secret: **`FIREBASE_SERVICE_ACCOUNT`** — a Google service-account JSON with Firebase deploy permissions (roles: Firebase Rules Admin / Cloud Datastore Index Admin / Firebase Develop Admin, or simply "Firebase Admin" for simplicity in a solo project). Documented in `docs/CICD.md`.

## 5. Store / signing (deferred, documented only)

Not wired in this pass. `docs/CICD.md` records the later plan so it is an additive step:
- A `deploy-mobile.yml` (or extension of `deploy.yml`) building signed release artifacts on `macos-latest` and `ubuntu-latest`.
- iOS: App Store Connect API key (`APP_STORE_CONNECT_KEY_ID`, `_ISSUER_ID`, `_KEY`), signing certificate + provisioning profile as secrets; `flutter build ipa` + upload to TestFlight via `xcrun altool` / `fastlane`.
- Android: upload keystore + `PLAY_SERVICE_ACCOUNT` secret; `flutter build appbundle --flavor prod` + upload to the Play internal track.
- Triggered on `release/*` (→ TestFlight / internal testing) and on `v*` tags (→ production track).
- These require the pending native homework (Apple provider/APNs, Android SHA-256/Play Integrity, signing assets), so they wait.

## 6. Docs & config changes

- `docs/GITFLOW.md` — the branching model, the exact commands for each flow (start/finish a feature, cut a release, hotfix), and how it maps to the stage/prod environments.
- `docs/CICD.md` — what each workflow does, the required/optional secrets, how to create the `FIREBASE_SERVICE_ACCOUNT` service account, and the deferred store-deploy plan.
- `CLAUDE.md` — change the Build/Test line from "Codemagic (CI)" to "GitHub Actions (CI + backend CD)"; note store signing is a later additive workflow.
- Memory build-state — record the pipeline + gitflow, the `FIREBASE_SERVICE_ACCOUNT` secret homework, and that CI is no longer billing-blocked.

## 7. Execution sequence (inline, main loop)

1. Merge PR #8 (`plan-6-requests`) → `main` (fast-forward) so `main` carries Plan 6 as the final pre-gitflow trunk commit.
2. Create `develop` from `main`; push it.
3. On a `feature/cicd-gitflow` branch off `develop`: add `ci.yml` (rewrite), `deploy.yml`, `docs/GITFLOW.md`, `docs/CICD.md`, the `CLAUDE.md` edit. Commit.
4. Open PR `feature/cicd-gitflow` → `develop`. This is the first live CI run on the public repo — watch it go green (fixing any real breakage).
5. Merge to `develop`; delete the feature branch.
6. Apply branch protection to `main` and `develop` via `gh api` (after the checks exist, so they can be named as required).
7. Update memory. Report the `FIREBASE_SERVICE_ACCOUNT` homework.

## 8. Non-goals (deferred)

- App-store / TestFlight / Play deploy + code-signing (§5) — needs the native signing homework.
- Cloud Functions deploy in CD — add when `firebase/functions/` exists (Plan 8).
- Automated version bumping / changelog generation (release-please, semantic-release) — manual `/bump` on the release branch for now.
- Staging as a *separate Firebase project* — the current single-project + split-database model is intentional; revisit only if prod/stage isolation becomes a hard requirement.
- Golden-image / device-farm testing in CI — later, with the QA phase.
