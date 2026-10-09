# Release Runbook — Convyve Go-Live

How to take Convyve from "code complete" (end of Plan 11: Release Hardening) to shipping in App Store + Play Store.

**Current state (end of Plan 11):** All code hardening is complete. Observability is wired to Firebase (Crashlytics + Analytics, Analytics non-throwing on errors). App Check is activated but enforcement is off. Settings screen is live (legal links, account deletion, sign-out, version). Paris soft-launch notice is in the app (dismissible in-app notice, not geo-gated). Firestore rules and Cloud Functions are compiled and ready to deploy. QA sweep is complete (215 tests green, no P0/P1).

**What's left before submission:** User-facing homework gates (backend, native auth, store accounts, legal hosting) + CI/CD verification + release mechanics.

---

## Phase 1 — Backend Setup

### 1.1 Upgrade Firebase to Blaze plan

**Why:** Cloud Functions (push notifications, account deletion cascade, post-meal reminders, ratings aggregation) only deploy on the **Blaze** (pay-as-you-go) plan. The free Spark plan blocks function deployment.

**Action:**
1. Go to [Firebase Console](https://console.firebase.google.com/project/not-eat-alone/usage/details)
2. Click **Upgrade** to Blaze
3. Confirm billing — keep spend limits on if you prefer
4. Verify upgrade completes (~5 min)

Once upgraded, `firebase deploy --only functions` will succeed on CI (currently the deploy job exits green with a notice).

### 1.2 App Check: Register attestation providers + debug token

**Why:** App Check prevents abuse of Firestore, Storage, and Cloud Functions. Enforcement is currently OFF (console settings apply after you register providers).

**Action:**

#### iOS: DeviceCheck

1. Firebase Console → Project Settings → App Check
2. Click the iOS app (`com.daki.noteatalone`)
3. Providers → **DeviceCheck** → Enable
4. For local development: **Add debug token**
   - In Xcode, run the app on a simulator (or real device if you have it)
   - App logs: `[DebugAppCheckToken]` — copy it
   - Paste into Firebase Console App Check → **Debug tokens** → add
5. Debug tokens expire in 24h; renew before testing

#### Android: Play Integrity API

1. Firebase Console → Project Settings → App Check
2. Click the Android app (`com.daki.noteatalone.stage` for now)
3. Providers → **Play Integrity API** → Enable
4. Google Play Console: go to your app → API and Services → enable Google Play Integrity API
5. For local development: generate a **debug token**
   - See `google_mobile_ads` / `play_integrity` docs if needed; Android's play_core library auto-generates one
   - Add it to Firebase Console App Check → **Debug tokens**

### 1.3 Enable App Check enforcement in Firebase Console

**Why:** Once providers are registered, you must explicitly turn ON enforcement per product. Until then, requests without App Check tokens are allowed.

**Action:**
1. Firebase Console → Firestore Security → **App Check** tab
2. Enforce App Check: **ON** (Firestore will reject unsigned requests)
3. Repeat for **Storage** → Rules → App Check enforcement → **ON**
4. Repeat for **Cloud Functions** → Quotas → App Check enforcement → **ON**

**⚠️ Test this in staging first** (against the `stage` database). Once enforcement is ON, unsigned clients can't write. Web + emulator clients need to be offline or behind a real App Check token.

### 1.4 Deploy Cloud Functions

Once Blaze is upgraded, functions deploy automatically via CI on every `develop` push (see `docs/CICD.md`). The functions are pre-built and tested:

- `onRequestCreated` — push to host when guest requests
- `onRequestUpdated` — push to guest on approve/deny
- `onMessageCreated` — push to other chat participant
- `postMealReminder` — hourly Pub/Sub, sends "rate your meal" nudges
- `onRatingCreated` — computes rolling ratings aggregate on target user

If you need to deploy manually (or this is your first time):
```bash
cd firebase/functions
npm ci
npm run build
cd ../..
firebase deploy --only functions
```

Verify in [Cloud Functions dashboard](https://console.cloud.google.com/functions?project=not-eat-alone&location=europe-west1) — all 5 functions should be green.

---

## Phase 2 — Native Auth + Push Notifications

### 2.1 iOS: APNs auth key

**Why:** Push notifications to iPhones require an APNs (Apple Push Notification service) authentication key.

**Action:**
1. Apple Developer → Certificates, Identifiers & Profiles → **Keys**
2. Create a new key → **Apple Push Notifications service (APNs)**
3. Download the `.p8` file (save it; only downloadable once)
4. Firebase Console → Project Settings → **Cloud Messaging** → Apple app → **APNs Authentication Key**
5. Upload the `.p8` file + key ID (from Apple Developer)
6. Verify: Firebase Cloud Messaging → Apple app → Key ID visible

Once uploaded, Firebase can send push via APNs.

### 2.2 Android: SHA-256 fingerprint + Play Integrity API

**Why:** Google Play requires your app's SHA-256 signing fingerprint for OAuth, Google Sign-In, and Play Integrity (used by App Check).

**Action:**

#### Get SHA-256 for signing keys

For **debug** (local development):
```bash
cd /path/to/not-eat-alone/android
./gradlew signingReport
# Look for the SHA-256 fingerprint under debugAndroidTest / debug
```

For **release** (Play Store signing):
- Go to Google Play Console → Your app → Setup → App signing
- Copy the **app signing certificate**'s SHA-256 (or download it and run `keytool -printcert -file <cert>`)

#### Add SHA-256 to Google Cloud

1. Google Cloud Console → APIs & Services → Credentials
2. For each OAuth client (Google Sign-In, if you use it) and App Check:
   - **Android**: Credentials → Android OAuth Client → add SHA-256 fingerprints
   - Select the **debug** SHA-256 for local dev
   - Select the **release** SHA-256 for Play Store submission

#### Enable Play Integrity API

1. Google Cloud Console → APIs & Services → Enable **Play Integrity API**
2. Firebase Console → App Check → Android provider → **Play Integrity** (should auto-detect after API is enabled)

### 2.3 iOS: Apple Sign-In provider + entitlement

**Why:** App Store policy: if you support third-party sign-in (Google), you must also support Sign in with Apple.

**Action:**
1. Apple Developer → Identifiers → Your app ID (`com.daki.noteatalone`)
2. Capabilities → enable **Sign In with Apple**
3. Firebase Console → Authentication → **Sign-in method** → enable **Apple**
4. Xcode → Runner → Signing & Capabilities → add **Sign in with Apple** capability (auto-adds entitlement)
5. Local verification: run on simulator, auth screen should show "Sign in with Apple" button

---

## Phase 3 — Maps & Places API

### 3.1 Reuse an existing GCP project for Maps (no new project needed)

**Current state:** Restaurant search is implemented end to end: `PlacesRestaurantSearchDataSource` (`lib/features/meal/data/datasources/`) → callable `searchRestaurants` (`firebase/functions/src/callable/search_restaurants.ts`) → Places API (New) Text Search, restricted to a Paris bounding box. `FakeRestaurantSearchDataSource` remains for tests (override `restaurantSearchRepositoryProvider`). **Remaining for you:** Maps-project keys + `PLACES_API_KEY` secret (steps 1–5), deploy + verify (below). Map view is not yet integrated (design deferred).

**Decision:** Convyve consumes Maps Platform from an **existing GCP project you own** (the "Maps project"). A Maps key is just an API key bound to whichever project enabled the APIs — it does not need to live in the Firebase project. Billing, quota and API enablement all belong to the Maps project; nothing is linked to Firebase.

**Three keys, never one.** Every key is restricted to the minimum; sharing one key across platforms/APIs defeats the restrictions.

| Key | Used by | Restricted to | Lives in |
|---|---|---|---|
| `convyve-places-server` | Cloud Function `searchRestaurants` | API: **Places API (New)** only | Secret Manager (Convyve Firebase project) |
| `convyve-maps-android` | `google_maps_flutter` on Android | API: **Maps SDK for Android** · app: packages `com.daki.noteatalone` **and** `com.daki.noteatalone.stage` + SHA-1 of debug, upload **and Play App Signing** certs | Build-time injection |
| `convyve-maps-ios` | `google_maps_flutter` on iOS | API: **Maps SDK for iOS** · app: bundle IDs `com.daki.noteatalone` **and** `com.daki.noteatalone.stage` | Build-time injection |

> Restriction entries must cover both flavors (prod + stage) — one entry per package/bundle ID + SHA-1.

**Why Places goes through a Cloud Function:** Places web-service keys can only be restricted by IP/referrer, not by app, so a Places key shipped in the binary is extractable and reusable by anyone. The key stays server-side; the client calls an App Check-enforced callable.

#### Action — in the Maps project (Google Cloud Console)

1. **APIs & Services → Library:** enable **Places API (New)**, **Maps SDK for Android**, **Maps SDK for iOS**. (Existing project → instant, no provisioning delay.)
2. **Billing:** confirm the project has an active billing account. Add a **Budget & alert** (e.g. 50 / 90 / 100 %) and per-API **quota caps** (APIs & Services → each API → Quotas → set a daily request limit) so a leaked key can't run up a bill.
3. **Credentials → Create credentials → API key** × 3 (names in the table above). For each: *Edit API key* → set **API restrictions** and **Application restrictions** per the table.
   - Android SHA-1s: debug (`keytool -list -v -keystore ~/.android/debug.keystore`), upload keystore, and the **App signing key certificate** from Play Console → Setup → App signing (add after Phase 4.2).
   - `convyve-places-server`: application restriction = **None** (Cloud Functions has no static egress IP). Compensate with the API restriction, Secret Manager, App Check enforcement and a quota cap.
4. **Optional keyless hardening (skip for v1):** instead of a Places key, call Places API (New) from the function with its service-account OAuth token plus the `X-Goog-User-Project: <maps-project-id>` header. Requires granting the function's service account **Service Usage Consumer** on the Maps project. Removes the secret entirely.

#### Action — in the Convyve Firebase project

5. **Store the Places key in Secret Manager** (never in `.env`, git or function config):
   ```bash
   firebase functions:secrets:set PLACES_API_KEY   # paste convyve-places-server value
   ```
6. **Callable `searchRestaurants`** — ✅ implemented in `firebase/functions/src/callable/search_restaurants.ts` (logic + tests in `src/lib/places.ts`, `test/places.test.ts`). Behavior:
   - `onCall({ region: 'europe-west1', secrets: [PLACES_API_KEY], enforceAppCheck: true }, …)`
   - Reject unauthenticated callers (`req.auth?.uid`).
   - Validate input (query ≤ 80 chars); results are locked to the Paris bounding box server-side — v1 is Paris-only. An empty query returns generic Paris restaurants (initial picker state; one billed request per picker open).
   - Call **Places API (New)** `places:searchText` / `places:searchNearby` with a **field mask** (`places.id,places.displayName,places.formattedAddress,places.location`) so you only pay for the SKU you use. Restrict with `includedTypes: ['restaurant']`.
   - Per-uid rate limit (30 calls/min, in-memory per instance — best-effort; `maxInstances: 10` + the Maps quota cap bound the worst case) and map the response to `{ placeId, name, address, lat, lng }`.
   - Upstream errors are never forwarded to the client (logged status only).
   - **Deploy:** `firebase deploy --only functions:searchRestaurants` (first deploy asks to grant the function access to the `PLACES_API_KEY` secret → accept).
7. **Enforce App Check on Functions** (Phase 1.3) — without it, `enforceAppCheck: true` still rejects, but the console toggle gives you metrics on blocked traffic.

#### Action — in the Flutter app

8. **Datasource swap** — ✅ done. `PlacesRestaurantSearchDataSource` maps the payload via `RestaurantDto` and throws `RepositoryReadException` / `RepositoryParseException`; the search field is debounced (400 ms) and the controller drops out-of-order responses. **Dev note:** debug builds need an App Check debug token registered (Phase 1.2) or the callable rejects them.
9. **Map view (optional for v1, design deferred → `/design` first):** add `google_maps_flutter` to `pubspec.yaml`; embed it on the meal detail screen for the restaurant pin. Inject the native keys at build time — **never commit them**:
   - **Android:** put `MAPS_API_KEY=…` in `android/local.properties` (gitignored) and read it in `android/app/build.gradle.kts` via `manifestPlaceholders["MAPS_API_KEY"]`; `AndroidManifest.xml` gets `<meta-data android:name="com.google.android.geo.API_KEY" android:value="${MAPS_API_KEY}"/>`.
   - **iOS:** put `MAPS_API_KEY = …` in a gitignored `ios/Flutter/Secrets.xcconfig` (`#include?` it from `Debug/Release.xcconfig`), expose it through `Info.plist` (`$(MAPS_API_KEY)`) and call `GMSServices.provideAPIKey(...)` in `AppDelegate`.
   - **CI (GitHub Actions / Codemagic):** store both as encrypted secrets and write the files in a pre-build step. The unsigned PR-gate builds can use an empty key (map renders blank, build still passes).
10. **Track:** if the map adds user actions (e.g. `map_opened`), add them via `/track` first.

#### Verify

- `cd firebase/functions && npm test && npm run build` and `flutter analyze && flutter test` (the Flutter side was written without running the toolchain — run these first).
- Release build on a real Android device and an iPhone: map tiles load, restaurant search returns real Paris results.
- Negative checks: calling `searchRestaurants` without App Check / without auth fails; the Android key does not work from a different package (a request with the key but a wrong package header → `API_KEY_ANDROID_APP_BLOCKED`).
- Maps project → APIs & Services → Metrics: filter by credential to confirm traffic per key and that quotas/budget alerts exist.

#### Operating notes

- **Rotate** a key by creating a new one, shipping it, then deleting the old one; a leaked Places key only needs `firebase functions:secrets:set` + redeploy (no app release).
- Because the Maps project is shared with other apps, per-key quotas and the metrics-by-credential view are how you isolate Convyve's usage and cost.
- Check Google Maps Platform's current Terms of Service and free-usage thresholds before launch; the display of Places data must follow attribution rules (Google logo on map views, "Powered by Google" when showing Places data on a non-Google map).

---

## Phase 4 — Signing & Store Accounts

### 4.1 iOS: Signing certificate + provisioning profile

**Why:** App Store requires a valid signing certificate. Codemagic handles signing automatically if you use Codemagic for builds; for local builds, you need the cert.

**Action:**

1. **Create/renew signing certificate:**
   - Apple Developer → Certificates, Identifiers & Profiles → **Certificates**
   - Create **iOS App Development** (for TestFlight) and **iOS Distribution** (for App Store)
   - Download `.cer` files
   - Codemagic Code Signing: upload the private key + cert, and Codemagic auto-manages provisioning profiles

2. **Provisioning profiles:**
   - App Store (Xcode auto-managing) or
   - Manual: Create → App Store profile → select signing cert → download + install in Xcode

3. **Xcode local build:**
   - Open `ios/Runner.xcworkspace` (not `.xcodeproj`)
   - Runner → Build Settings → Signing → select cert + provisioning profile
   - `flutter build ipa --release` should succeed

4. **For CI (Codemagic):** Managed automatically; no local cert needed.

### 4.2 Android: Keystore + Play Console upload key

**Why:** Google Play requires your app signed with a keystore and tracks signing certificates across all versions.

**Action:**

1. **Create keystore (if you don't have one):**
   ```bash
   keytool -genkey -v -keystore ~/convyve-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias convyve-release
   # Follow prompts for password, org name, etc.
   ```

2. **Configure Android build:**
   - Create `android/key.properties` (gitignored):
     ```properties
     storeFile=/path/to/convyve-release.jks
     storePassword=<your-password>
     keyPassword=<your-key-password>
     keyAlias=convyve-release
     ```
   - `android/app/build.gradle` already reads these (see template)

3. **Google Play Console app (next section):**
   - Create new app → Get Play Console's **upload key certificate**
   - For your keystore, get SHA-256: `keytool -list -v -keystore ~/convyve-release.jks`
   - Keep the keystore safe; Google Play *locks your cert* once you use it

4. **Local test:**
   ```bash
   flutter build appbundle --release
   # → build/app/outputs/bundle/release/app-release.aab
   ```

### 4.3 Store accounts

#### App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Create new app:
   - Name: **Convyve**
   - Bundle ID: `com.daki.noteatalone`
   - SKU: `convyve-v1` (internal only)
   - Platform: iOS
3. Fill in basic metadata (name, subtitle, category)
4. Later (Phase 5): Add privacy policy, rating questionnaire, screenshots, full description

#### Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Create new app:
   - Name: **Convyve**
   - App ID: auto-generated
   - Category: Social
3. Store listing:
   - Short description (80 chars): "Meet for a meal, don't eat alone"
   - Full description (4000 chars): see Phase 5
   - Store icon, screenshots: Phase 5
4. Setup:
   - **App signing:** create internal testing track, upload your signed bundle (v1.0.0+1)
   - Play Console will show you its **app signing certificate** (SHA-256) — add this to Google Cloud + Firebase App Check (Phase 2)

---

## Phase 5 — Legal Documents & Store Metadata

### 5.1 Host Privacy + Terms

**Current state:** `docs/legal/privacy.md` + `docs/legal/terms.md` exist (drafted, GDPR-aware). `lib/core/config/legal_urls.dart` has placeholders pointing to `https://convyve.com/privacy` and `https://convyve.com/terms`.

**Action:**

1. **Choose hosting:**
   - **GitHub Pages** (free): Push to a public repo, enable Pages in settings, files served as HTML
   - **Notion** (free, email-gated): Paste markdown, publish to web, copy URL
   - **Your domain** (convyve.com): Host the rendered HTML

2. **Render + upload:**
   - Markdown → HTML (use a Markdown-to-HTML converter, e.g., `marked`, GitHub's web renderer, or Notion's "publish")
   - Upload to your chosen host
   - Note the URLs (e.g., `https://convyve.com/privacy`)

3. **Update `lib/core/config/legal_urls.dart`:**
   ```dart
   const privacyPolicyUrl = 'https://your-domain/privacy';
   const termsOfServiceUrl = 'https://your-domain/terms';
   ```
   - Both URLs must be HTTPS and accessible to real users (not `localhost`)
   - App Store + Play Store verify these before approval

4. **Verify in app:**
   - Settings screen → "Privacy Policy" / "Terms of Service" buttons
   - Tap → should open web view with the hosted document

### 5.2 Store metadata

**Current state:** `docs/store/listing.md` exists (drafted). iOS + Android require metadata submitted via their store consoles.

#### App Store Connect

1. Your app → **Pricing and Availability**
   - Price: Free
   - Territories: at least France (Part of launch scope; expand post-v1)

2. Your app → **App Information**
   - **Privacy Policy URL:** link from Phase 5.1
   - **Support URL:** your email or support page (e.g., `mailto:support@convyve.com` or a contact form)

3. Your app → **General App Information**
   - App Category: **Social Networking**
   - Rating Questionnaire: Answer "Does your app access/collect user data?" → **Yes**
     - Select all applicable categories (minimal for v1: location, contacts if people-search, maybe "Sensitive info in communications")
     - Apple generates a privacy label automatically

4. Your app → **App Store Listing**
   - **Name:** Convyve (120 chars max)
   - **Subtitle:** Don't eat alone (30 chars max)
   - **Description:** (4000 chars)
     ```
     Connect with people over a meal. Post your favorite restaurant and a time,
     match 1:1 with someone nearby, and try something new together.
     
     Features:
     — Meal-first matching: every connection centers on trying a specific restaurant
     — Women-only meals: post private events for friends only
     — Block & report: safety always on
     — Real profiles: all users are verified
     ```
   - **Keywords:** restaurant, dating, friends, social, meal (100 chars comma-separated)
   - **Promotional Text:** (170 chars, updatable post-launch)
     - "Try a new restaurant this week. Match 1:1 with someone nearby."
   - **Support URL:** as above

5. Your app → **Screenshots**
   - 5–8 screenshots (see Phase 5.3)
   - Formats: iPhone 6.9" (1320×2868), iPhone 6.5" (1242×2688)
   - Use release build only (debug build looks different)

#### Google Play Console

1. Your app → **Store listing**
   - Same metadata as above
   - **Privacy Policy URL:** link from Phase 5.1
   - **Support email:** your support contact (required)
   - **Store icon:** 512×512 PNG (or see pubspec.yaml asset)
   - **Feature graphic:** 1024×500 PNG (banner, optional for v1)

2. Your app → **Content rating questionnaire**
   - Answer a ~20-question form about content
   - For Convyve (social, no explicit content): safe to answer "No" to most
   - Play Console assigns a rating (e.g., 13+)

3. Your app → **Data safety**
   - **Data being collected & shared:**
     - Location (required for meal discovery)
     - Name, profile photo (required for matching)
     - Messages (in chats)
     - Ratings (after a meal)
   - **Data privacy:**
     - Link to your Privacy Policy
     - Is data encrypted in transit? Yes
     - Can users request data deletion? Yes (Settings → Delete Account)

4. Your app → **Screenshots**
   - Phone format: 1080×1920 (16:9) or larger
   - 5–8 screenshots (see Phase 5.3)
   - Use release build

### 5.3 Screenshots

**Timing:** Take these from the release build AFTER Phase 4 (signing). Debug builds look visually different.

**Process:**
1. Build release APK/IPA locally or via Codemagic
2. Run on iPhone 17 Pro Simulator or Pixel 8 Emulator
3. Navigate to 5 key screens (e.g., home feed, meal detail, chat, profile, settings)
4. Take screenshot (Cmd+S simulator, or use Android Studio)
5. Resize to required dimensions:
   - **iOS:** 1320×2868 (6.9"), 1242×2688 (6.5"), or 1242×2208 (6.5" old)
   - **Android:** 1080×1920 (or 16:9 scaled)
6. Add optional text overlay (e.g., "Find local meals") if your design tool supports it
7. Upload to App Store Connect / Play Console

---

## Phase 6 — CI/CD Verification

### 6.1 Verify CI gates pass

**Current state:** GitHub Actions workflows (`.github/workflows/ci.yml`) run on every PR into `develop`/`main`. Four jobs (3 required checks, 1 optional "Functions build"):

1. **Analyze & test** — `flutter analyze` + `flutter test` (215 tests, all green)
2. **Build Android (stage, unsigned)** — APK compile (verify no build errors)
3. **Build iOS (stage, no codesign)** — Xcode + Pods compile (verify no build errors)
4. **Functions build & test** — Cloud Functions TypeScript (all green)

**Action:**
1. Ensure all CI checks are passing on `main` (or the release branch you're pushing)
2. The three Flutter checks are currently **required** (branch protection); **Functions build should be added as a 4th required check** via GitHub UI (Settings → Branches → Branch protection rules → Edit `main` → Require status checks to pass)

### 6.2 Manual device QA

**Current state:** Automated tests cover the happy path (215 tests). Manual device testing catches visual regressions, flow issues, and edge cases that simulators miss.

**Action:** Run the full checklist from `docs/TEST-PLAN.md`:

#### Universal edge cases (every release)

- [ ] Timezone math: Date-keyed data respects local TZ, not UTC
- [ ] Date rollover at midnight: "today" advances without manual refresh
- [ ] Long strings (≥1000 chars) don't crash
- [ ] Long lists (≥100 items) render without dropped frames

#### Feature checklists (per spec)

- [ ] Meal creation: create a meal in Paris, verify it appears in discovery
- [ ] Meal discovery: launch app, see the feed, distance/time sorting correct
- [ ] Requests & matching: request to join, host approves, `matches/{mealId}` creates
- [ ] Chat: message in a match, see send/receive, read receipt shows "Seen"
- [ ] Push notifications: send a test notification via FCM, app receives it + deep-links correct
- [ ] Safety: block a user, verify they don't appear in discovery/chat
- [ ] Ratings: post-meal card appears, submit 1–5 stars, target's profile badge updates
- [ ] Settings: view legal links (open web view), delete account, sign out
- [ ] Soft Paris notice: first launch shows "Coming soon in Paris" dismissible banner

#### Device requirement

- At least one **real device** (iPhone or Android) — simulators can't test:
  - App Check (needs real device attestation)
  - Push notifications (background foreground state)
  - GPS location (simulator GPS is fake)
  - Camera/photo picker (some flows may use this)

**If not possible:** Document the blockers and note in the QA summary. App Store reviewers will test on real devices.

---

## Phase 7 — Release Process

### 7.1 Gitflow release branch

**Current state:** The repo uses gitflow (`docs/GITFLOW.md`):
- `develop` = integration branch (stage DB, functions deployed here first)
- `main` = production branch (stable releases)
- `feature/*` = feature branches (branch off `develop`)
- `release/*` = release branches (cut from `develop`, merged to `main` + `develop`)

**Action:**

1. **Ensure `develop` is stable:**
   ```bash
   git checkout develop
   git pull origin develop
   # Verify CI is green
   ```

2. **Cut release branch:**
   ```bash
   git checkout -b release/v1.0.0
   ```

3. **Bump version in `pubspec.yaml`:**
   ```yaml
   version: 1.0.0+1
   # Format: X.Y.Z+buildNumber
   # X = major, Y = minor, Z = patch (semver)
   # buildNumber = monotonic int, increments every build
   ```

4. **Update `CHANGELOG.md`:**
   ```markdown
   ## [1.0.0] - 2026-09-23

   ### Added
   - Initial release: meal-first matching, chat, ratings, safety (block/report), push notifications

   ### Removed
   - N/A

   ### Fixed
   - N/A
   ```

5. **Commit:**
   ```bash
   git add pubspec.yaml CHANGELOG.md
   git commit -m "chore(release): bump to v1.0.0"
   ```

6. **Push & open PR to `main`:**
   ```bash
   git push -u origin release/v1.0.0
   gh pr create --base main --title "Release v1.0.0" --body "First production release"
   ```

7. **Wait for CI to pass,** then merge (via GitHub UI or `gh pr merge`)

### 7.2 Tag & publish

Once the release PR is merged to `main`:

```bash
git checkout main
git pull origin main
git tag v1.0.0
git push origin v1.0.0
```

This triggers:
- **CD deploy job:** `firebase deploy --only firestore,storage,functions` to production
- **GitHub Release:** auto-generated release notes with the changelog

### 7.3 Submit to stores

Once tagged + deployed:

#### App Store

1. Xcode or Codemagic: build + sign with **App Store distribution certificate**
2. App Store Connect → Your app → TestFlight → **Build** (select your signed IPA)
3. Wait for processing (~5–30 min)
4. **Submit for Review** (or use **Phased Release** for a softer rollout)
5. Apple review: 1–3 days, may ask for clarifications (usually privacy-related)

#### Play Store

1. Codemagic or locally: `flutter build appbundle --release`
2. Google Play Console → Your app → **Internal testing** → **Upload new build**
3. Wait for processing (~5 min)
4. **Internal testing → Production:** promote to production track
5. Submit for Review
6. Google Play review: usually <24h, rare rejections

### 7.4 Post-release

1. **Announce:** blog post, social media, in-app notification
2. **Monitor:** Crashlytics, Analytics (Firebase Console)
3. **Hotfix workflow** (if needed):
   ```bash
   git checkout main
   git pull origin main
   git checkout -b hotfix/1.0.1
   # Fix the bug
   git commit -m "fix(auth): sign-in race condition"
   git push -u origin hotfix/1.0.1
   gh pr create --base main --title "Hotfix v1.0.1"
   # Merge, tag, deploy (same as 7.1–7.3 but version is 1.0.1+2)
   ```

---

## Known Follow-Ups

After v1.0.0 ships:

- **Ratings GDPR completeness:** Account deletion does not yet purge `ratings` (where the user is the rater or target). Add this to `deleteAccount` Cloud Function after feedback from privacy review.
- **Pre-meal reminders:** Scheduled nudges 1–2 hours before meal time (non-goal for v1, deferred pending user feedback)
- **Comments on ratings:** Users can add short text; add moderation queue if spam surfaces
- **Edit/delete ratings:** Allow up to 24h to withdraw a rating
- **Live map integration:** Place card shows restaurant on map (setup steps in Phase 3.1 §9; v1 uses list-only discovery)
- **Geofence expansion:** Auto-prompt "expand search beyond Paris" if no results (v1 Paris-only soft-launch)

---

## Troubleshooting

| Issue | Likely cause | Fix |
|---|---|---|
| CI: "No Firebase App '[DEFAULT]' has been created" | `lib/firebase_options.dart` missing or gitignored | Re-run `flutterfire configure` + commit the file |
| CI: Functions build fails on Spark | Blaze plan not upgraded | Upgrade Firebase to Blaze in console (Phase 1.1) |
| iOS build fails: signing certificate not found | Xcode doesn't have the cert or provisioning profile | Codemagic: re-fetch Code Signing profiles; locally: `flutter clean && cd ios && pod install --repo-update` |
| Android build fails: upload keystore not found | `android/key.properties` missing or wrong path | Create keystore (Phase 4.2), add `key.properties`, verify paths |
| App Store review rejection: "Missing privacy URL" | `lib/core/config/legal_urls.dart` not updated | Verify both URLs are live + HTTPS and App Store can fetch them |
| Play Store review rejection: "App signing certificate mismatch" | Signed with wrong keystore or mismatched SHA-256 | Verify Play Console's upload cert SHA-256 matches your keystore (Phase 4.2) |
| Push notifications not arriving | App Check enforcement ON but debug token not added | Add App Check debug token to Firebase (Phase 1.2) |
| Firestore rules rejected by App Check | Enforcement ON but app not signing requests | Verify app has valid App Check token (simulator/emulator may need debug token added) |

---

## One-Time Setup Summary

Before your first submission:

1. ✅ Blaze plan upgraded
2. ✅ App Check registered + enforcement ON
3. ✅ Cloud Functions deployed
4. ✅ APNs key uploaded
5. ✅ Android SHA-256 registered
6. ✅ Apple Sign-In enabled
7. ✅ Maps project: Places + Maps SDK enabled, 3 restricted keys, budget + quota caps; `PLACES_API_KEY` in Secret Manager; `searchRestaurants` deployed (Phase 3)
8. ✅ iOS signing certificate + provisioning profile
9. ✅ Android keystore + Play Console upload key
10. ✅ App Store Connect app created
11. ✅ Google Play Console app created
12. ✅ Privacy + Terms hosted (HTTPS)
13. ✅ `lib/core/config/legal_urls.dart` updated with real URLs
14. ✅ Store metadata + screenshots uploaded
15. ✅ CI gates passing on `main`
16. ✅ Manual device QA complete
17. ✅ Ready for `release/v1.0.0` → `main` → tag + deploy + submit

---

## Questions?

- **Gitflow unclear?** See `docs/GITFLOW.md`
- **CI/CD setup unclear?** See `docs/CICD.md`
- **QA checklist unclear?** See `docs/TEST-PLAN.md`
- **Missing a step?** File an issue or ask in the repo's Discussions tab
