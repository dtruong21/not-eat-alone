# CI/CD

All pipelines run on **GitHub Actions** (free on this public repo, including
macOS runners). Branching model: `docs/GITFLOW.md`.

## Workflows

### `.github/workflows/ci.yml` — the quality gate

Runs on every PR into `main` / `develop` / `release/**` / `hotfix/**`, and on
the post-merge commit of `develop` / `main`. Three jobs, Flutter pinned to the
`.fvmrc` version:

| Job | Runner | What |
|---|---|---|
| `Analyze & test` | ubuntu | `pub get` → `build_runner` → `flutter analyze --no-fatal-infos` → `flutter test` |
| `Build Android (stage, unsigned)` | ubuntu | `flutter build apk --flavor stage --debug` — compile/flavor verification |
| `Build iOS (stage, no codesign)` | macOS | `flutter build ios --flavor stage --debug --no-codesign` — iOS + Pods compile, no certs |

Generated files (`*.freezed.dart`, `*.g.dart`) are git-ignored, so every job
runs `build_runner`. These three are the required status checks for branch
protection.

### `.github/workflows/deploy.yml` — backend CD + releases

| Trigger | Job | What |
|---|---|---|
| push to `develop` / `main` | `Deploy Firebase backend` | `firebase deploy --only firestore,storage` to project `not-eat-alone` |
| push tag `v*` | `Publish GitHub Release` | GitHub Release with auto-generated notes |

The Firebase project is single (`.firebaserc`), and the rules files are shared,
so one deploy keeps both the `(default)` and `stage` databases current.
`develop` is the integration deploy; `main` re-asserts the same rules at release
time (idempotent). **Functions are excluded** until `firebase/functions/`
exists — when Cloud Functions land (Plan 8), add `functions` to the `--only`
list in `deploy.yml`.

## Required secret: `FIREBASE_SERVICE_ACCOUNT`

Until this repo secret is set, the deploy job **exits green with a notice** and
deploys nothing (the pipeline is never red for a missing secret). To enable
backend CD:

1. In the [Firebase / Google Cloud console](https://console.firebase.google.com/project/not-eat-alone/settings/serviceaccounts/adminsdk),
   generate a new private key for a service account. For a solo project the
   default Firebase Admin SDK service account is fine; least-privilege is
   Firebase Rules Admin + Cloud Datastore Index Admin + Storage Admin.
2. Copy the **entire JSON** file contents.
3. Repo → Settings → Secrets and variables → Actions → **New repository secret**:
   - Name: `FIREBASE_SERVICE_ACCOUNT`
   - Value: the JSON.
4. The next push to `develop` / `main` will deploy.

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
