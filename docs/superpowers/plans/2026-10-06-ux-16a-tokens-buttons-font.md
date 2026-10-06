# UX Pass Part B, Plan 16a: Tokens, Colours, Buttons, Font, Contrast Tests

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the app's theme-level UX defects found by the audit: unreadable secondary text, buttons that look like surfaces, invisible spinners' colour, unreadable error text, cards that melt into the page, and the font that is downloaded at runtime and applied to only 4 of 15 text styles. Lock the results with contrast and grep tests so they cannot regress.

**Architecture:** All changes are at the design-system layer (`lib/core/design/`) plus mechanical call-site sweeps in `lib/features/*/presentation/`. No domain, data, rules, or routing changes. A new `context.wp` accessor replaces repeated `Theme.of(context).extension<WarmPlayfulExtensions>()!`. Contrast is enforced by unit tests computed from the real tokens and the built `ThemeData`; "no border colour as text" by a source-grep test.

**Tech Stack:** Flutter via FVM (`fvm flutter ...`), Material 3 `ThemeData`, `flutter_test`. Capture harness `make ux-capture` (see `ux_audit/README.md`) for before/after verification.

Spec: `docs/superpowers/specs/2026-10-05-ux-pass-design.md` (§6 has the owner decisions). Evidence and exact lists: `docs/ux/AUDIT.md` (findings X-01..X-05, X-08, backlog B1-1..B1-4, B1-6..B1-8). Measured numbers: `docs/ux/contrast-measured.txt`.

## Global Constraints

- Flutter via FVM always. `fvm flutter analyze`: 0 errors/warnings, no new lints in touched files. `fvm flutter test` green after every task.
- Dependency rule `presentation → application → domain ← data` is untouched. No Firebase imports outside `data/`.
- Tokens for all colours, spacing, type, radius; no magic numbers. New values go into `lib/core/design/tokens.dart` first.
- No `firestore.rules`, Cloud Functions, CI workflow, or `integration_test` behaviour changes. Do not run `firebase deploy`.
- Dark mode is first-class: every colour change is made for both brightnesses and covered by a test.
- Owner decisions that bind this plan: card colour deepened (light `surface` `#FBE8D8`) plus a soft shadow where cards are built; coral fill unchanged; labels on coral become brown (`#3D2E1F`) in both modes.
- WCAG: text 4.5:1, non-text UI 3:1 (disabled controls exempt). Ratios in this plan are hand-computed; the contrast test in Task 1 is the authority. If a value in this plan fails the test, adjust the value minimally (keep the hue), record the final value in the report.
- E2E and widget tests locate widgets by key/text, not by colour; if a test asserts the old colours, update the assertion to the new token (never delete the test).
- Do not commit anything under `graphify-out/` or `.superpowers/`. Commit trailer: the `Co-Authored-By:` line the harness specifies at that time.
- Capture runs use only the simulators `Convyve E2E` and `Convyve UX Small`; never the generic `iPhone 17 Pro`.

---

### Task 1: Palette tokens, `context.wp`, scheme mapping, contrast test

**Files:**
- Modify: `lib/core/design/tokens.dart`, `lib/core/design/theme.dart`
- Create: `test/core/design/contrast_test.dart`
- Modify (only if they construct `WarmPlayfulExtensions`): any test or file that fails to compile after the extension gains fields (grep `WarmPlayfulExtensions(`).

**Interfaces:**
- Produces in `tokens.dart`: light `muted = Color(0xFF7A6352)`, light `surface = Color(0xFFFBE8D8)`; new in both palettes `dangerText` (light `0xFFA84A35`, dark `0xFFF09781`) and `onAccent` (`0xFF3D2E1F` in both); new `abstract final class WarmPlayfulSize { static const double actionHeight = 56; static const double minTap = 48; }`; new `abstract final class WarmPlayfulElevation { static const double card = 2; }`.
- Produces in `theme.dart`: `WarmPlayfulExtensions` gains `dangerText`, `onAccent`, `shadow` (copyWith/lerp updated); `extension WarmPlayfulContext on BuildContext { WarmPlayfulExtensions get wp => Theme.of(this).extension<WarmPlayfulExtensions>()!; }`. `ColorScheme`: `onPrimary: onAccent`, `onSurfaceVariant: muted`, `error: dangerText`, `onError: bg` (the current mode's bg).
- `shadow`: light `Color(0x403D2E1F)`, dark `Color(0x99000000)`.

- [ ] **Step 1: Write the contrast test (red).** `test/core/design/contrast_test.dart` with this helper and assertions (extend, don't shrink):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    group('contrast ($brightness)', () {
      final theme = buildTheme(brightness);
      final scheme = theme.colorScheme;
      final wp = theme.extension<WarmPlayfulExtensions>()!;
      final bg = theme.scaffoldBackgroundColor;

      test('body text on page and cards >= 4.5', () {
        expect(contrast(scheme.onSurface, bg), greaterThanOrEqualTo(4.5));
        expect(contrast(scheme.onSurface, scheme.surface), greaterThanOrEqualTo(4.5));
      });
      test('secondary text (wp.muted, onSurfaceVariant) on page and cards >= 4.5', () {
        expect(contrast(wp.muted, bg), greaterThanOrEqualTo(4.5));
        expect(contrast(wp.muted, scheme.surface), greaterThanOrEqualTo(4.5));
        expect(scheme.onSurfaceVariant, wp.muted);
      });
      test('error text on page and cards >= 4.5', () {
        expect(scheme.error, wp.dangerText);
        expect(contrast(scheme.error, bg), greaterThanOrEqualTo(4.5));
        expect(contrast(scheme.error, scheme.surface), greaterThanOrEqualTo(4.5));
      });
      test('label on primary (coral) >= 4.5, onError on error >= 4.5', () {
        expect(contrast(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5));
        expect(contrast(scheme.onError, scheme.error), greaterThanOrEqualTo(4.5));
      });
      test('muted icons/borders used as UI parts >= 3.0 against bg', () {
        expect(contrast(wp.muted, bg), greaterThanOrEqualTo(3.0));
      });
    });
  }

  test('light card vs page stays visibly separated by token choice', () {
    // Documented, not a WCAG rule: the deeper surface plus shadow (Task 6).
    final t = buildTheme(Brightness.light);
    expect(t.colorScheme.surface, const Color(0xFFFBE8D8));
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** (`fvm flutter test test/core/design/contrast_test.dart`): muted 3.9-4.2, error ~2.8, onPrimary 2.18.
- [ ] **Step 3: Implement the tokens, extension fields, `context.wp`, scheme mapping** as in Interfaces. Update every `WarmPlayfulExtensions(` constructor and `copyWith`/`lerp`.
- [ ] **Step 4: Run the contrast test, expect PASS.** If a hand-computed value fails, adjust minimally and note it.
- [ ] **Step 5: Gates:** `fvm flutter analyze`, full `fvm flutter test`. Fix assertions in existing tests that pinned old colours (point them at the new token).
- [ ] **Step 6: Commit** `feat(design): readable secondary text, brown-on-coral labels, danger text token, deeper card colour (tokens + contrast tests)`

---

### Task 2: Button system

**Files:**
- Modify: `lib/core/design/theme.dart`
- Modify (call sites): the 14 `FilledButton`s and the 3 unthemed `OutlinedButton`s listed in `docs/ux/AUDIT.md` X-01/X-02 (`signin_screen.dart`, `phone_verify_screen.dart`, `age_gate_screen.dart`, `profile_setup_screen.dart`, `profile_edit_screen.dart`, `create_meal_screen.dart`, `meal_detail_screen.dart`, `request_inbox_tile.dart`, `report_sheet.dart`, `rating_sheet.dart`, `post_meal_card.dart`)
- Create: `test/core/design/button_theme_test.dart`

**Interfaces:**
- Consumes: Task 1 (`onAccent`, `WarmPlayfulSize`, `context.wp`).
- Produces: M3 semantics. `FilledButton` = primary (fill `accent`, label `onAccent`, disabled fill `border` / label `subtle`); `FilledButton.tonal` (fill `surface`, label `text`); `OutlinedButton` (label `text`, side `muted` 1.5 px, radius `md`); `TextButton` unchanged; all `minimumSize` height `WarmPlayfulSize.minTap`, radius `WarmPlayfulRadius.md`, symmetric horizontal padding `s5`. Spinners inside buttons use the button's foreground colour (Task 2 changes the colour arguments only; the shared `AppButton` is Plan 16b).

- [ ] **Step 1: Theme tests first (red)** in `button_theme_test.dart`, both brightnesses, pumping a `MaterialApp(theme: buildTheme(b), home: Scaffold(body: Column(...)))` with an enabled and a disabled `FilledButton`, a `FilledButton.tonal`, and an `OutlinedButton`. Assert via `tester.widget<Material>(find.descendant(of: find.byType(FilledButton), matching: find.byType(Material)).first).color`: enabled fill == `scheme.primary`; label `DefaultTextStyle` colour == `scheme.onPrimary`; disabled fill != enabled fill; tonal fill == `scheme.surface`; each button's rendered height >= 48; the outlined side colour == `wp.muted`.
- [ ] **Step 2: Implement** `filledButtonTheme`, `filledTonalButtonTheme`, `outlinedButtonTheme`, and `elevatedButtonTheme` (keep consistent, `foregroundColor: onAccent`) in `theme.dart`; set the chip `secondaryLabelStyle` colour to `onAccent`; FAB theme (`floatingActionButtonTheme`: `backgroundColor: accent`, `foregroundColor: onAccent`) if not already explicit.
- [ ] **Step 3: Call-site cleanup.** `grep -n "styleFrom\|ButtonStyle" lib/features`: remove per-site overrides that only restate the old look (vertical-only `padding` that zeroed horizontal padding, `shape` radius `sm`, hard-coded fills). KEEP overrides that are semantic: the Deny button's danger foreground/border in `request_inbox_tile.dart` (it is deliberate; make it use `wp.dangerText`). Change spinner colour arguments from `colors.onPrimary` to the button's foreground (`Theme.of(context).colorScheme.onPrimary` is now brown, which is correct on the enabled coral fill; for disabled-while-loading buttons see the next step).
- [ ] **Step 4: Spinner-while-disabled.** The 9 button spinners (`AUDIT.md` X-03) sit on a disabled (grey) fill. Until `AppButton` (Plan 16b) lands, make them visible: keep the button *enabled-looking* while loading by passing `onPressed: isSubmitting ? () {} : handler` is NOT allowed (tap-through); instead set `style: FilledButton.styleFrom(disabledBackgroundColor: scheme.primary, disabledForegroundColor: scheme.onPrimary)` on those 9 buttons only, and spinner `color: scheme.onPrimary`. Add one widget test per file already testing the in-flight state (or one shared test) asserting the spinner colour contrasts >= 3:1 with the button fill.
- [ ] **Step 5: Gates** (analyze, full test). Update any existing test that asserted old fills/labels.
- [ ] **Step 6: Commit** `feat(design): primary buttons are coral with brown labels; secondary/outlined hierarchy; visible in-flight spinners`

---

### Task 3: Sweep border colour out of text and icon colours

**Files:**
- Modify: the 13 files in `docs/ux/AUDIT.md` X-01 tables (27 text uses, 8 icon uses, 1 decorative): `signin_screen.dart`, `phone_verify_screen.dart`, `age_gate_screen.dart`, `profile_setup_screen.dart`, `discovery_screen.dart`, `restaurant_search_screen.dart`, `create_meal_screen.dart`, `meal_detail_screen.dart`, `request_inbox_screen.dart`, `chat_list_screen.dart`, `chat_list_tile.dart`, `chat_screen.dart`, `message_bubble.dart`, `rating_badge.dart`, `post_meal_card.dart`, `settings_screen.dart`, `request_inbox_tile.dart`, `profile_form.dart`, `message_composer.dart`, `safety_tips_card.dart`
- Create: `test/core/design/no_border_colour_as_text_test.dart`

**Interfaces:**
- Consumes: `context.wp` (Task 1).
- Produces: zero `colorScheme.outline` / `colors.outline` references under `lib/features/`.

- [ ] **Step 1: Grep test first (red).** The test reads every `.dart` file under `lib/features/` and fails if any line matches `RegExp(r'\.outline\b(?!Variant)')` (so `outlineVariant` is allowed), listing `file:line`. Run: expect it to list ~36 hits.
- [ ] **Step 2: Replace.** Text colour and meaningful icons: `colors.outline` → `context.wp.muted` (import the theme file if needed). The disabled send icon in `message_composer.dart` → `context.wp.subtle`. The bullet dot in `safety_tips_card.dart` → `context.wp.muted`. Where a file keeps a local `colors`/`textTheme` variable, add `final wp = context.wp;` in the same scope rather than calling `context.wp` repeatedly. Do not change layout or copy.
- [ ] **Step 3: Run the grep test (green), then** analyze and full test. Fix existing tests that read the old colour.
- [ ] **Step 4: Commit** `fix(ui): secondary text and meaningful icons use the muted token, never the border colour (grep-guarded)`

---

### Task 4: Danger text, container roles, snackbar and chip colours (both modes)

**Files:**
- Modify: `lib/core/design/theme.dart`
- Create: `test/core/design/container_roles_test.dart`
- Modify (only to fix breakage): files that use `colorScheme.error` for text (13 sites, `AUDIT.md` X-04) need no edits; review the other `colorScheme.error` users listed there.

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: `primaryContainer = palettePeach`, `secondaryContainer = surface`, `tertiaryContainer = paletteSage`, `errorContainer` (light `Color(0xFFF9D9CF)`, dark `Color(0xFF5A2E24)`), and `on*Container` = light brown `WarmPlayfulColorsLight.text` for primary/secondary/tertiary in both modes (pastel mid-tones) and `onErrorContainer` = `text` for the current mode; `inverseSurface` = brown `#3D2E1F` (light) / cream `#FAEBD7` (dark) with `onInverseSurface` = the opposite; `snackBarTheme` (floating, radius `md`, background `inverseSurface`, content style `onInverseSurface`, action colour `accent` in dark / `palettePeach` in light); `chipTheme.selectedColor` unchanged with `secondaryLabelStyle` `onAccent`.

- [ ] **Step 1: Test first (red)** `container_roles_test.dart`, both brightnesses: every `on*Container` on its container >= 4.5; `onInverseSurface` on `inverseSurface` >= 4.5; the built `snackBarTheme.backgroundColor == scheme.inverseSurface`.
- [ ] **Step 2: Implement** in the `ColorScheme.copyWith` and `snackBarTheme`. If a pair fails 4.5, nudge the container/`on` value minimally and record it.
- [ ] **Step 3: Review the other users** of `colorScheme.error` (`request_inbox_tile.dart:246-247` Deny, `settings_screen.dart:58/150/161`, `age_gate_screen.dart:118`): they get darker in light mode; confirm no visual regression in the Task 7 capture. The Requests tab badge (`Badge`) uses `error` as its background: check it still reads (label colour `onError`); if it now looks too dark, set the badge colours explicitly in `app_shell.dart` (`backgroundColor: wp.danger`, `textColor: wp.onAccent`) and verify the pair is >= 4.5.
- [ ] **Step 4: Gates; commit** `feat(design): container roles, snackbar and chip colours for both modes; error text reaches AA`

---

### Task 5: Bundle Nunito, apply it to every text style, drop runtime `google_fonts`

**Files:**
- Create: `assets/fonts/Nunito-Regular.ttf`, `Nunito-Medium.ttf`, `Nunito-Bold.ttf`, `Nunito-ExtraBold.ttf`, `assets/fonts/OFL.txt`
- Modify: `pubspec.yaml` (fonts section; remove `google_fonts`), `pubspec.lock` (via `fvm flutter pub get`), `lib/core/design/theme.dart`, `ux_audit/capture_test.dart` (it awaits `GoogleFonts.pendingFonts()`; remove that wait), `docs/DESIGN.md` (typography note)
- Create: `test/core/design/typography_test.dart`

**Interfaces:**
- Produces: family `Nunito` declared in `pubspec.yaml` with weights 400/500/700/800; `buildTheme` gives EVERY non-null `TextStyle` in `textTheme` `fontFamily: WarmPlayfulFonts.body`; `ThemeData(fontFamily: WarmPlayfulFonts.body)`.
- Font source (SIL OFL 1.1, free to bundle): `https://github.com/google/fonts` repo, `ofl/nunito/`. Prefer static files; if only the variable font `Nunito[wght].ttf` exists there, instantiate static weights with fontTools: `pip install fonttools` then `fonttools varLib.instancer "Nunito[wght].ttf" wght=400 -o Nunito-Regular.ttf` (repeat 500/700/800). Record the source URL, commit and file sizes in the report. Copy the licence text into `assets/fonts/OFL.txt`.

- [ ] **Step 1: Test first (red)** `typography_test.dart`: for both brightnesses, every non-null style in `buildTheme(b).textTheme` has `fontFamily == 'Nunito'`; a pubspec test (read `pubspec.yaml` as text) asserts `google_fonts:` is absent and the four `assets/fonts/Nunito-*.ttf` paths are declared and exist on disk; `lib/` contains no `package:google_fonts` import (grep).
- [ ] **Step 2: Add the font files, OFL.txt, pubspec `fonts:` section** (family `Nunito`; `weight: 400/500/700/800` entries), remove `google_fonts`, run `fvm flutter pub get`.
- [ ] **Step 3: theme.dart:** replace `GoogleFonts.nunitoTextTheme(base.textTheme)` with `base.textTheme.apply(fontFamily: WarmPlayfulFonts.body)` and add `fontFamily: WarmPlayfulFonts.body` to each explicit `TextStyle` in the `copyWith`; add the licence to the app's licence registry (`LicenseRegistry.addLicense` in `lib/main_common.dart` or a small `lib/core/design/font_license.dart` reading `assets/fonts/OFL.txt`) so the Licences page (Plan 18) lists it.
- [ ] **Step 4: Remove `GoogleFonts.pendingFonts()` waits** from `ux_audit/capture_test.dart` (keep a short bounded settle delay if the harness needs it). Run `fvm flutter analyze ux_audit`.
- [ ] **Step 5: Gates** (analyze, full test), and a debug build compile check: `fvm flutter build ios --simulator --debug --flavor stage -t lib/main_stage.dart` (use the project's real flavour/target as in `Makefile`/`docs/CICD.md`) to prove the assets resolve.
- [ ] **Step 6: Commit** `feat(design): bundle Nunito, apply it to every text style, drop runtime google_fonts (GDPR, offline, fidelity)`

---

### Task 6: Separate cards from the page (shadow where cards are built)

**Files:**
- Modify: `lib/core/design/theme.dart` (`cardTheme`), and the card builds: `discovery_screen.dart:~200`, `chat_list_tile.dart:~65`, `restaurant_search_screen.dart:~155`, `meal_detail_screen.dart:~473` (restaurant card), plus any other `Material(color: ...surface...)` / `Container(decoration: color: surface)` card surfaced by `grep -rn "colors.surface\|colorScheme.surface" lib/features`
- Create: `test/core/design/card_separation_test.dart`

**Interfaces:**
- Consumes: `WarmPlayfulElevation.card`, `wp.shadow` (Task 1).
- Produces: cards render with `elevation: WarmPlayfulElevation.card`, `shadowColor: wp.shadow`, `surfaceTintColor: Colors.transparent`; `cardTheme` carries the same elevation and shadow colour. Full-width bars (message composer, bottom sheets, app bar) are NOT shadowed.

- [ ] **Step 1: Test first (red):** a widget test per card kind that pumps it (or `buildTheme(light)` `cardTheme`) and asserts `elevation == WarmPlayfulElevation.card` and `shadowColor == wp.shadow`; light `surface` vs `bg` token ratio is recorded in the test as a comment, not asserted.
- [ ] **Step 2: Implement** on the listed builders and `cardTheme`. Keep radius, padding and layout identical. Check the `border` token still reads against the deeper light surface (chip borders, drag handle); if it vanishes (< 1.1:1), darken the light `border` token one step (`0xFFE8D5C0` as a starting point) and note it.
- [ ] **Step 3: Gates; commit** `feat(design): soft shadow and deeper surface separate cards from the cream page`

---

### Task 7: Docs, verification capture, final gates

**Files:**
- Modify: `docs/DESIGN.md` (colours: muted, surface, dangerText, onAccent; buttons: FilledButton is primary, tonal/outlined/text hierarchy; typography: Nunito bundled; card shadow), `CHANGELOG.md` (`[Unreleased]` `### Changed`/`### Fixed`: readable secondary text, buttons, error text, fonts bundled, card separation), `docs/TEST-PLAN.md` (new contrast/typography/no-border-as-text tests)
- Create: `docs/ux/16a-verification.md`

- [ ] **Step 1: Docs** accurate to what shipped (no overclaiming; list what is test-guarded).
- [ ] **Step 2: Capture** `make ux-capture DEVICE='Convyve E2E' OUT=16a-light` and `OUT=16a-dark` (the matrix script is not needed). For `01_signin`, `22_discover_data`, `40_meal_detail_open`, `52_requests_data`, `60_chat`-equivalent, `83_settings`, `93_discover_error` (use the real file names under `ux_audit/out/iphone17-light-default/`), view the before (the audit cell) and after PNG, and write `docs/ux/16a-verification.md`: per shot, what changed, and any remaining defect (e.g. a pale label, a clipped overflow) with severity. Fix defects that belong to this plan; list the rest as inputs for plans 16b/17/18.
- [ ] **Step 3: Final verification, once, in order:** `fvm flutter analyze` (0 errors/warnings), `fvm flutter test` (all green), `make e2e` (all green; the theme change must not break E2E finders). Rerun once if the intermittent launch hang hits.
- [ ] **Step 4: Commit** `docs: UX plan 16a (tokens, buttons, font): design system, changelog, test plan, verification capture`
- [ ] **Step 5:** The controller pushes and opens the PR to `develop` after the final review.
