# Release Runbook

How to take {{PROJECT_NAME}} from "code complete" to shipping in App Store + Play Store.

---

## Step 0 — One-time setup (~$124 total)

| Item | Cost | Required for |
|------|------|--------------|
| Apple Developer Program | $99/yr | iOS dev build, TestFlight, App Store |
| Google Play Console | $25 one-time | Play Store submission |
| Expo account | Free | EAS Build, OTA updates |
| Privacy/Terms hosting (GitHub Pages or similar) | Free | App Store / Play Store requirement |

Sign up:
- Apple: https://developer.apple.com/programs/enroll/
- Google: https://play.google.com/console/signup
- Expo: `npx eas-cli login`

---

## Step 1 — Initialize EAS

```bash
npx eas-cli@latest init
```

Creates the project on EAS, writes `extra.eas.projectId` into `app.json`. Replace any placeholder values.

---

## Step 2 — Brand assets

- **App icon**: 1024×1024 PNG, no transparency, no rounded corners (Apple adds them). → `assets/icon.png`
- **Adaptive icon (Android)**: 1024×1024, safe zone 432×432 center. → `assets/adaptive-icon.png`
- **Splash screen**: 1284×2778 PNG. → `assets/splash.png`
- **Notification icon (Android)**: 96×96 monochrome white-on-transparent.

Wire in `app.json` under `expo.icon`, `expo.android.adaptiveIcon`, `expo.splash`.

---

## Step 3 — Host Privacy + Terms

Required by App Store and Play Store. Markdown lives in `docs/legal/`. Host options:

- **GitHub Pages** (free, ~10 min) — push to a public repo, enable Pages.
- **Notion** — paste, "Publish to web", copy URL.
- **Your domain** — host the rendered HTML.

Update `.env`:
```
EXPO_PUBLIC_PRIVACY_URL=https://your.url/privacy
EXPO_PUBLIC_TERMS_URL=https://your.url/terms
```

---

## Step 4 — Deploy Cloud Functions

If you have any (account-deletion cascade, server-side validation, etc.):

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

First-time setup may require enabling billing (Blaze plan). Most MVPs stay within free tier.

---

## Step 5 — Cut the first dev build (Android first, free)

Android dev builds don't require Apple Developer Program. Start there:

```bash
npx eas-cli build --profile development --platform android
```

For iOS (needs Apple Developer):
```bash
npx eas-cli build --profile development --platform ios
```

---

## Step 6 — Wire native auth providers (after dev build)

With a real bundle ID from a dev build, create OAuth credentials:

- **Google iOS**: Google Cloud → Credentials → Create iOS OAuth Client ID, bundle ID = your production bundle.
- **Google Android**: Google Cloud → Credentials → Create Android OAuth Client ID. SHA-1 from `eas credentials`.
- **Apple Sign-In** (required if Google is enabled, per App Store policy): Apple Developer → Identifiers → enable "Sign In with Apple" capability. Firebase Console → Authentication → enable Apple. Install `expo-apple-authentication`.

---

## Step 7 — Store metadata

Fill in `docs/STORE_METADATA.md`. Required:

- Short description (Play Store, 80 chars)
- Full description (4000 chars each store)
- Keywords (App Store, 100 chars comma-separated)
- Promotional text (App Store, 170 chars, updatable post-submit)
- What's New (per version)
- Privacy policy URL (Step 3)
- Support URL (your contact email or page)

---

## Step 8 — Screenshots

Take from the actual dev build (NOT Expo Go — looks different). Use iPhone 17 Pro simulator and Pixel 8 emulator.

**iOS sizes:**
- 6.9" iPhone: 1320×2868
- 6.5" iPhone: 1242×2688

**Android:**
- Phone: 1080×1920 minimum, 16:9

5 screens recommended — pick the most product-defining ones.

---

## Step 9 — TestFlight / Internal track

```bash
npx eas-cli build --profile production --platform all

# After builds finish:
npx eas-cli submit --profile production --platform ios       # → TestFlight
npx eas-cli submit --profile production --platform android   # → Play Internal
```

First iOS submission asks for the ASC App ID — create the listing in App Store Connect first.

Invite 5–10 testers. Run a 1–2 week closed beta. Listen.

---

## Step 10 — Public launch

1. Bump `version` in `app.json`
2. Update `CHANGELOG.md`
3. Update "What's New" in store metadata
4. `eas build --profile production --platform all`
5. `eas submit --profile production --platform all`
6. App Store review: 1–3 days
7. Play Store review: usually <24h

---

## Recurring releases

```bash
# After feature work
# 1. Update CHANGELOG.md
# 2. Bump version in app.json (PATCH for fixes, MINOR for features)
git tag v0.X.Y
npx eas-cli build --profile production --platform all
npx eas-cli submit --profile production --platform all
```

OTA updates (JS-only changes, no native deps changed):
```bash
npx eas-cli update --branch production
```

---

## When things break

- `eas credentials` — re-sync provisioning / keystores
- `eas build --clear-cache` — wipe the build cache
- **App Store rejection** — usually privacy. Missing privacy URL or account deletion not actually deleting (Cloud Function in Step 4).
- **"App icon required" rejection** — Step 2 isn't done.
