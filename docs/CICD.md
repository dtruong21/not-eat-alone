# CI/CD

All pipelines run on **GitHub Actions** (free on this public repo, including
macOS runners). Branching model: `docs/GITFLOW.md`.

## Workflows

### `.github/workflows/ci.yml` — the quality gate

Runs on every PR into `main` / `develop` / `release/**` / `hotfix/**`, and on
the post-merge commit of `develop` / `main`. Jobs:

| Job | Runner | Runs when | What |
|---|---|---|---|
| `Detect changes` | ubuntu | always | Classifies the PR diff into `app` / `functions` / `rules` flags (pushes to `develop`/`main` run everything). Docs-only PRs run no heavy job |
| `Analyze & test` | ubuntu | `app` | `pub get` → `build_runner` → `flutter analyze --no-fatal-infos` → `flutter test` (+ a `TZ=Pacific/Kiritimati` re-run of the local-time display tests) |
| `Build Android (stage, unsigned)` | ubuntu | `app` | `flutter build apk --flavor stage --debug` — compile/flavor verification (Gradle cache) |
| `Build iOS (stage, no codesign)` | macOS | `app`, not a draft PR | `flutter build ios --flavor stage --debug --no-codesign` — iOS + Pods compile, no certs (CocoaPods cache) |
| `Functions build & test` | ubuntu | `functions` | `firebase/functions`: `npm ci` → `build` → `lint` → `test` (npm cache) |
| `Firestore rules tests` | ubuntu | `rules` | `firebase/rules-test`: the rules suite against the local Firestore emulator (Java 21, emulator jar cached) |
| `E2E (emulator, iOS sim)` | macOS | after `Analyze & test` is green, not a draft PR | **Non-blocking.** `make e2e`: the `integration_test/` suite on a freshly created iOS Simulator against the Firebase Emulator Suite (Node 22, Java 21, `firebase-tools@13`). 100 min job timeout; each attempt capped at 40 min and retried once on failure/hang; emulator logs uploaded as an artifact on failure or retry |
| `CI OK` | ubuntu | always | One aggregate check: green when every job that had to run passed (**skipped is fine**; failed/cancelled is not). E2E is excluded |

**What changes which flags** (`Detect changes`): `app` ← `lib/ test/ integration_test/ ios/ android/ assets/ scripts/`,
`pubspec.yaml|lock`, `analysis_options.yaml`, `.fvmrc`, `Makefile`, `firebase.json`, `.env.example`;
`functions` ← `firebase/functions/`; `rules` ← `firebase/firestore.rules|indexes`, `storage.rules`,
`firebase/rules-test/`, `firebase.json`. Any change under `.github/` (workflows, actions, dependabot) sets all three.
Everything else (docs, changelog, bug files…) runs nothing but `CI OK`.

**Shared setup.** `.github/actions/setup-flutter` (a local composite action) seeds `.env` from `.env.example`,
installs Flutter at the version in **`.fvmrc` (the only pin — there is no second copy in the workflow to drift)**,
restores the pub cache, runs `pub get` and `build_runner`. Generated files (`*.freezed.dart`, `*.g.dart`) are
git-ignored, so every Flutter job needs it.

**Other levers:** superseded PR runs are cancelled (post-merge `develop`/`main` runs are never cut short);
workflow `permissions: contents: read`; every job has a `timeout-minutes`; Dependabot
(`.github/dependabot.yml`) opens weekly grouped PRs for Actions, the two npm projects and pub
(`firebase-functions` majors are excluded — upgrade that one deliberately).

**Branch protection (configured outside this repo, via `gh api` / the GitHub UI).** Because jobs can now be
skipped by the path filter, require the single **`CI OK`** check (plus E2E later) instead of the individual job
names: a required check that is *skipped* counts as passing, and `CI OK` fails when any job that ran failed.
Until protection is switched over, the previously required checks (`Analyze & test`, `Build Android`,
`Build iOS`) keep working — a skipped required check passes — but `Functions build & test` and
`Firestore rules tests` are only enforced once `CI OK` is the required check.

**`E2E (emulator, iOS sim)` is deliberately not a required check yet.** It runs
a real Xcode build, simulator and emulators on a shared macOS runner, and the
suite has a known occasional launch hang (see `docs/TEST-PLAN.md`, "End-to-end
tests (emulator)"). Promote it to a required check once it has been green
without a retry on a handful of consecutive PRs (a reasonable bar: ~5) and its
typical runtime is stable. Until then a red run is a signal to investigate, not
a merge blocker. As with the others, branch protection is configured outside
this repo.

The E2E time caps are generous on purpose: every `integration_test/*.dart` file triggers its own Xcode build (about 150 s on the runner), so the whole suite needs more than 20 minutes on a cold runner. The first real runs were killed by a 20-minute per-attempt cap while still running tests normally (not hung), hence 40 min per attempt and a 100 min job cap (setup ~10 min + 2 attempts with headroom).

**Not yet run on GitHub.** These workflows are validated with `actionlint` and the change-detection logic was exercised locally, but the first real PR / `develop` push should be watched.


### Backend CD — chained behind CI

| Where | Trigger | Job | What |
|---|---|---|---|
| `ci.yml` → `deploy-firebase.yml` | push to `develop` / `main`, **only after `CI OK` is green** | `Deploy Firebase backend` | `firebase deploy --only firestore,storage,functions` to project `not-eat-alone` |
| `deploy-firebase.yml` | manual (*Actions → Deploy Firebase → Run workflow*) | same job | Redeploy a chosen branch **without** the CI gate — e.g. after a failed deploy or after setting the secret |
| `deploy.yml` (workflow "Release") | push tag `v*` | `Publish GitHub Release` | GitHub Release with auto-generated notes |

A commit whose analyze/test/builds/functions/rules jobs fail never reaches the backend: the deploy job is
`needs: ci-ok` in `ci.yml` (E2E is excluded — it is non-blocking). The deploy lives in a reusable workflow
(`deploy-firebase.yml`, `workflow_call` + `workflow_dispatch`) so the same steps serve the chained and the manual
path, and the chain does not depend on `workflow_run` (which only reads workflow files from the default branch).

Safeguards in the deploy job: **stale-commit skip** (two quick pushes can finish CI out of order; if the branch
tip has moved past the commit being deployed, this run exits with a notice and the newer commit deploys),
**one deploy at a time per branch** (queued, never cancelled mid-flight), a 30-minute timeout, and the secret
guard below.

The Firebase project is single (`.firebaserc`), and the rules files are shared,
so one deploy keeps both the `(default)` and `stage` databases current.
`develop` is the integration deploy; `main` re-asserts the same rules (and
functions) at release time (idempotent).

### Cloud Functions deploy requirements (Plan 8 + Plan 10)

- **Firebase Blaze plan required.** Cloud Functions (and their outbound
  network calls, e.g. to FCM) only deploy on the pay-as-you-go **Blaze**
  plan — the free **Spark** plan cannot deploy functions at all. The CD job
  will fail at the `functions` deploy step until the project is upgraded in
  the [Firebase console](https://console.firebase.google.com/project/not-eat-alone/usage/details).
- **Region: `europe-west1`.** All functions in `firebase/functions/` are
  pinned to `europe-west1` (matches the Firestore project's home region).
  Deploys create/update functions in that region only.
- **Scheduled functions (Plan 10 onwards).** The `postMealReminder` scheduled
  function (Pub/Sub hourly, europe-west1) requires **Cloud Scheduler**,
  which is automatically provisioned and managed by the Firebase CLI on
  deploy; no extra configuration needed.
- **Rating aggregate function (Plan 10).** The `onRatingCreated` trigger
  (Firestore document trigger) updates `AppUser` rating aggregate fields
  (`ratingCount`, `ratingAvg`) on every new rating — requires **Blaze**.
- **CI gate: `functions-build`.** Every PR/push compiles the Functions
  TypeScript and runs its Jest suite before merge — a broken trigger can't
  reach `develop`/`main`, independent of whether Blaze/deploy secrets are set.
- **Service account role.** The `FIREBASE_SERVICE_ACCOUNT` secret's service
  account needs the **Cloud Functions Admin** role in addition to the
  rules-deploy roles listed below (Firebase Rules Admin, Cloud Datastore
  Index Admin, Storage Admin) — without it, the `functions` deploy target
  fails with a permissions error even on Blaze.

## Required secret: `FIREBASE_SERVICE_ACCOUNT`

Until this repo secret is set, the deploy job **exits green with a notice** and
deploys nothing (the pipeline is never red for a missing secret). To enable
backend CD:

1. In the [Firebase / Google Cloud console](https://console.firebase.google.com/project/not-eat-alone/settings/serviceaccounts/adminsdk),
   generate a new private key for a service account. For a solo project the
   default Firebase Admin SDK service account is fine; least-privilege is
   Firebase Rules Admin + Cloud Datastore Index Admin + Storage Admin +
   Cloud Functions Admin.
2. Copy the **entire JSON** file contents.
3. Repo → Settings → Secrets and variables → Actions → **New repository secret**:
   - Name: `FIREBASE_SERVICE_ACCOUNT`
   - Value: the JSON.
4. The next push to `develop` / `main` will deploy.

**Deploying rules without the secret.** While the secret is unset CI deploys
nothing, so rule/index changes (e.g. the `matches` create rule) must be
deployed manually: `firebase deploy --only firestore --project not-eat-alone`.

This is the same kind of key as `scripts/seed/service-account.json` (seeding);
keep both out of git — they already are.

## Deferred: app-store / TestFlight / Play (not wired yet)

Blocked on the native signing homework (Apple provider + APNs, Android SHA-256 +
Play Integrity, signing assets). When ready, add a signed-build workflow
(e.g. `deploy-mobile.yml`) — an additive change, nothing here needs to move:

- **iOS**: secrets `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
  `APP_STORE_CONNECT_KEY` (p8), signing cert + provisioning profile.
  `flutter build ipa --flavor prod` → upload to TestFlight (`xcrun altool` or
  fastlane), on `macos-latest`.
- **Android**: upload keystore secrets + `PLAY_SERVICE_ACCOUNT`.
  `flutter build appbundle --flavor prod` → upload to the Play internal track.
- **Triggers**: `release/*` → TestFlight / internal testing; `v*` tag →
  production track.

## Notes

- CI was previously billing-blocked on a private repo; going public removed
  that. Red CI now means a real code failure — debug it, don't wait it out.
- Locally, verify the same gate with `fvm flutter analyze` + `fvm flutter test`
  before pushing.
- **iOS flavor plist (known gap):** committed Firebase configs live per-flavor
  (`ios/config/{prod,stage}/GoogleService-Info.plist`,
  `android/app/src/{prod,stage}/google-services.json`). Android's gradle
  sourceSets auto-select the flavor file; iOS has **no** build phase copying the
  flavor plist into `ios/Runner/GoogleService-Info.plist` (that path is
  git-ignored scratch). CI copies the stage plist explicitly before the iOS
  build. Follow-up (needed for signed prod iOS builds): add an Xcode run-script
  build phase that copies `ios/config/${FLAVOR}/GoogleService-Info.plist` into
  place per configuration, so local + release flavor builds pick the right one
  without a manual copy.
