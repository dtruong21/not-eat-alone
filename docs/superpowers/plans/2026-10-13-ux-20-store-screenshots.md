# UX Plan 20: Store Screenshots and French Listing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship store-ready screenshot sets (English and French, iOS and Google Play sizes) with real captions, and a French App Store / Google Play listing, all committed under `docs/store/`.

**Architecture:** No new capture mode. The existing capture harness (`make ux-capture`, 73 shots per cell) already reaches every hero screen; plan 19 added `UX_LOCALE=fr`. Task 1 makes the seeded demo world locale-aware (French chat messages, bios and meal notes under `UX_LOCALE=fr`, so a French store shot is not half English). Task 2 adds a dependency-free Flutter compositor (a `flutter test` file that lays out a branded canvas: caption + rounded, shadowed screenshot, writes PNGs) because the machine has no ImageMagick/Pillow. Task 3 writes the French listing and rewrites listing.md section 6 and the checklist around the real files.

**Tech Stack:** Flutter (FVM), the capture harness in `ux_audit/`, `dart:ui` canvas rendering inside `flutter_test`, bundled Nunito font, `sips` for size checks.

## Global Constraints

- Flutter via FVM. `fvm flutter analyze` 0 errors AND 0 warnings; `fvm flutter test` green. No new dependencies. No changes to `lib/` (app code), `firestore.rules`, `firebase/functions`, `.github/workflows`, `ios/`, `android/`.
- Capture runs use ONLY the simulators `Convyve E2E` and `Convyve UX Small`, never the generic `iPhone 17 Pro`. Long commands run in the background with a log and bounded polling; never kill processes you did not start (a stale `flutter_tester` from another session may exist).
- Store images: PNG, no transparency (opaque RGB background), no device-status-bar tricks, no fabricated UI: every screenshot is a real capture of the real app. Seeded demo content must look like plausible Paris users (no real people, no real photos: the harness serves placeholder gradient avatars).
- Output sizes: iOS 6.9" = 1290 x 2796 px (accepted 6.9" size) and Google Play phone = 1080 x 1920 px portrait. Each file < 8 MB. Record in `docs/store/listing.md` that the sizes must be re-checked against the stores' current requirements at submission time (they change).
- Locales: `en` and `fr`. Captions are short (<= 2 lines at the compositor's font size), in the app's voice (French informal "tu" in captions is fine for a consumer app; native review pending, same as plan 19).
- Brand "Convyve" and URLs untranslated. Nothing is uploaded or submitted anywhere: this plan only prepares files. Store listing text in French is a DRAFT for native review.
- Committed binaries: at most 5 shots x 2 locales x 2 store sizes = 20 PNGs, each < 1.5 MB (downscale/optimize with `sips` if larger); the raw 1206 x 2622 captures stay in the gitignored `ux_audit/out/`.
- Do NOT run `dart format` on directories or on files you do not otherwise edit. Commit trailer: the `Co-Authored-By:` line the harness specifies at that time. Never commit `.superpowers/`, `graphify-out/`, `ux_audit/out/`.

---

### Task 1: Locale-aware demo world

**Files:**
- Modify: `ux_audit/support/world.dart` (seed text depends on the locale), `ux_audit/capture_test.dart` (pass the locale into the world builder; wherever English finders are mapped to French for `UX_LOCALE=fr` extend the `_fr` map for any seeded text the test looks up), `ux_audit/README.md`
- No `lib/` changes.

**Interfaces:**
- `UxWorld` / `seedUsers()` / `seedMeals()` take (or read from a top-level const) `String locale` (`'en'` default, `'fr'`). Under `fr`: the 18 chat messages in the main chat (world.dart ~lines 610-700), the past-meal chat (~740-742), user bios (~170-180), meal notes/dietary text, and the rating comment, are natural French (informal, young-adult Paris voice, same meaning as the English; keep the emoji). Names, restaurants, times, prices and ids are unchanged. English output stays byte-identical.
- Anything in `capture_test.dart` that finds seeded text by its English string must still work under both locales.

- [ ] **Step 1:** Read `ux_audit/support/world.dart` and the places `capture_test.dart` looks up seeded text. Write the French content as a parallel table keyed the same way as the English (do not duplicate the world-building logic).
- [ ] **Step 2:** Add a small Dart unit test that is NOT part of the app test suite's device run but runs under `fvm flutter test ux_audit/support/world_locale_test.dart`: both locales produce the same message count/ids/ordering and different text for `fr`; no `''`-style escaping issues. (If `ux_audit/` has no test setup, put the test under `test/ux_audit/` importing the world file; check `ux_audit/README.md` for how the harness is organised first.)
- [ ] **Step 3:** Run one cell in French (`UX_LOCALE=fr make ux-capture DEVICE='Convyve E2E' OUT=20-fr-light-default`, must exit 0, 0 `UXOVERFLOW`, 73 PNG) and view `22_discover_data`, `40_meal_detail_open`, `52_requests_data`, `63_chat_messages`, `73_rating_sheet` (or `76_chat_safety_sheet`) to confirm no English seeded text remains. Also run the English cell (`OUT=20-light-default`) and confirm 73 PNG / 0 overflow (regression proof).
- [ ] **Step 4:** Commit `feat(ux): locale-aware demo world for French store captures`.

---

### Task 2: Store frame compositor

**Files:**
- Create: `tool/store_frames/store_frames_test.dart` (a `flutter test` file; run with `fvm flutter test tool/store_frames/store_frames_test.dart`), `tool/store_frames/captions.dart` (const captions per locale + per shot), `tool/store_frames/README.md`
- Output (committed): `docs/store/screenshots/{en,fr}/ios-6.9/NN_name.png` (1290 x 2796) and `docs/store/screenshots/{en,fr}/play-phone/NN_name.png` (1080 x 1920), `docs/store/screenshots/README.md` (file list + how to regenerate)

**Interfaces:**
- Input: the raw captures from `ux_audit/out/20-light-default/` (en) and `ux_audit/out/20-fr-light-default/` (fr), by these source names, in this order: `22_discover_data` (1 Discover), `40_meal_detail_open` (2 Meal detail), `52_requests_data` (3 Requests), `63_chat_messages` (4 Chat), `76_chat_safety_sheet` or `73_rating_sheet` (5 Safety / ratings: pick the one that tells the safety story best after viewing both). The test reads PNGs from a path given by `--dart-define=STORE_SRC_EN=...` / `STORE_SRC_FR=...` (defaults to the folders above) and SKIPS cleanly (not fails) when they are absent, so the normal `fvm flutter test` stays green on machines without captures.
- Look: opaque background from the design tokens (warm accent family from `lib/core/design/tokens.dart`, e.g. the cream/surface and the primary accent), caption top-aligned in Nunito ExtraBold (bundled font), white or ink text chosen for contrast >= 4.5:1, one or two lines; the screenshot below it scaled to fit width with margin, rounded corners (radius from the tokens' largest radius scaled), soft shadow; the bottom of the phone may bleed off the canvas bottom for the tall iOS canvas (hero framing) but the interactive content must stay visible. Same layout rules for the Play canvas (9:16) with a smaller screenshot.
- Rendering: lay out with `RepaintBoundary` + `RenderRepaintBoundary.toImage(pixelRatio: ...)` inside `tester.runAsync`, `ui.Image.toByteData(format: png)`, write bytes with `dart:io`. Fonts: the test must load the bundled Nunito (`FontLoader` from `assets/fonts` as the app's pubspec declares) so the PNG does not use the test font (Ahem blocks).

- [ ] **Step 1:** Write the compositor test + captions const (English and French captions: five per locale, from `docs/store/listing.md` section 6 shortened to fit two lines at the chosen size; French drafted by you, marked for native review).
- [ ] **Step 2:** Run it with both source folders; check the files exist with the exact pixel sizes (`sips -g pixelWidth -g pixelHeight`), sizes < 1.5 MB (reduce with `sips -s format png` re-save or lower `pixelRatio` only if needed), then LOOK at every output PNG (Read tool) and iterate on layout until captions never clip, never overlap the phone, contrast is fine, and French captions fit two lines.
- [ ] **Step 3:** Write `docs/store/screenshots/README.md` and `tool/store_frames/README.md` (regeneration steps: capture both locales, run the test with the defines).
- [ ] **Step 4:** Gates: `fvm flutter analyze` 0/0, `fvm flutter test` green (the compositor test skips when sources are absent; confirm by running it once with a bogus path). Commit `feat(store): framed store screenshots for iOS and Google Play, English and French`.

---

### Task 3: Listing text (English cleanup + French draft) and checklist

**Files:**
- Modify: `docs/store/listing.md`
- Create: `docs/store/listing.fr.md`

**Interfaces / content:**
- `listing.md` section 6 ("Screenshots & Captions") now references the actual files under `docs/store/screenshots/en/...` with the final English captions (same as the compositor's const), sizes, and the re-check-requirements note. Section 3/5 content stays, but fix anything now inaccurate vs the shipped app (e.g. mentions that contradict the product: "Ratings & show-up records", "Free to use, forever", women-only, Paris-only, 18+: verify against `docs/PRD.md` and the app; flag, do not silently rewrite promises). Keep it a DRAFT; update the "Last updated" date; the checklist items "Screenshots are high-quality, localized" tick or reword accordingly; add a "Localizations" item (French listing in `listing.fr.md`, native review, French legal pages are user homework).
- `listing.fr.md`: French (France) version of every user-visible store field with character counts verified by a script (include the script output or counts): App name `Convyve`; subtitle <= 30 chars; promotional text <= 170 chars; Google Play short description <= 80 chars; full description (<= 4000 chars) mirroring the English structure in natural, warm French with "tu"/"vous" decision made explicit: App Store copy conventionally addresses the reader formally OR informally, so choose "tu" to match the in-app voice and note it as a decision for the owner; keywords field <= 100 chars (French search terms, comma-separated, no spaces after commas, no duplicates of the app name/category words: e.g. repas, dîner, restaurant, rencontre, sortie, convive, table, amis, paris, manger); What's New (first release); screenshot captions (identical to the compositor's French captions); age rating note; support/privacy/terms URL placeholders marked as needing French pages. Top banner: "DRAFT: needs native French review".
- Character counts: write a tiny shell/awk check (no new dependency) and paste its output, or assert in a Dart test; counts must be of the final text.

- [ ] **Step 1:** Re-read `docs/PRD.md` (product promises) and the English listing; list inaccuracies.
- [ ] **Step 2:** Write `listing.fr.md`; verify counts.
- [ ] **Step 3:** Update `listing.md` (section 6 + checklist + localizations note) and `docs/ux/19-verification.md` follow-up line for the store listing (mark drafted); add a CHANGELOG bullet under Unreleased ("Store: framed screenshots (EN/FR), French listing draft").
- [ ] **Step 4:** Final verification once: `fvm flutter analyze` 0/0, `fvm flutter test`, `git status` shows only intended files, image sizes re-verified. Commit `docs(store): French listing draft, screenshot captions and checklist`.
- [ ] **Step 5:** The controller pushes and opens the PR after the final review.
