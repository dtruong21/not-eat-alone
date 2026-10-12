# Design System — Warm Playful (Flutter)

Soft pastel palette, rounded corners, gentle spring motion. The kind of design language that says "this app is for *you*, not your manager."

**Best for:** consumer apps, wellness, habit + journal, kids/family, meditation, food, anything where warmth beats efficiency.

**Platforms:** iOS, Android, web (Flutter).

## Aesthetic principles

1. **Never pure white. Never pure black.** The bg is `#FFFAF3` (cream); dark mode bg is `#231811` (warm brown).
2. **Round more than feels right, then round more.** Buttons radius 16, cards 24. Sharp edges look hostile in this system.
3. **Color tells the story.** A 5-color accent palette (peach / sage / butter / lavender / sky) supplements the single accent. Use it for category tags, illustrations, empty states.
4. **Motion has a touch of bounce.** Spring physics, gentle overshoot. Never aggressive — `damping: 14`, not 8.
5. **Type carries weight.** Nunito 700/800 on titles. Friendly but confident.

## Tokens

Full reference: [`tokens.dart`](tokens.dart). Theme builder: [`theme.dart`](theme.dart).

Widgets read theme via `Theme.of(context)` for Material colors, and via the `WarmPlayfulExtensions` theme extension for the category palette + warm-specific semantic colors:

```dart
final wp = Theme.of(context).extension<WarmPlayfulExtensions>()!;
Container(color: wp.peach);                 // category palette
Text('caption', style: TextStyle(color: wp.muted)); // warm-brown muted text
```

### Color — surfaces (never pure white/black)

| Token | Light | Dark |
|---|---|---|
| `bg` (`scaffoldBackgroundColor`) | `#FFFAF3` (cream) | `#231811` (warm dark) |
| `surface` (`colorScheme.surface`) | `#FBE8D8` (warm peach) | `#2E211A` |
| `border` (`wp.border`) | `#E8D5C0` | `#3F2F25` |
| `divider` (`wp.divider`) | `#F7EBDD` | `#352720` |
| `shadow` (`wp.shadow`) | `#3D2E1F` @ 25% | `#000000` @ 60% |

Light `surface` is a deeper peach so cards read against the cream `bg` (about 1.15:1: too close to separate on its own, so cards also carry a soft shadow, see `Card`). `border` and `divider` are **decorative**: they are not text or icon colours (a test fails if `colorScheme.outline` is used as one under `lib/features`; `outlineVariant`, the divider token, is not guarded and only the two sign-in `Divider`s use it).

### Color — text (warm browns, not grays)

| Token | Light | Dark |
|---|---|---|
| `text` (`colorScheme.onSurface`) | `#3D2E1F` | `#FAEBD7` |
| `muted` (`wp.muted`, also `colorScheme.onSurfaceVariant`) | `#7A6352` | `#B5A18C` |
| `subtle` (`wp.subtle`) | `#B5A18C` | `#8C7563` |
| `onAccent` (`colorScheme.onPrimary`) | `#3D2E1F` | `#3D2E1F` |
| `dangerText` (`colorScheme.error`, `wp.dangerText`) | `#A84A35` | `#F09781` |

- `muted` is the secondary-text and meaningful-icon colour: at least 4.5:1 on `bg` and on `surface` in both modes.
- `subtle` is for **disabled** foregrounds and decoration only (below 4.5:1).
- `onAccent` is the label colour on coral (`accent`) fills (brown, not cream).
- `dangerText` is the error-text colour (at least 4.5:1 on `bg` and `surface`); `danger` stays terracotta for fills only.
- All of the above are pinned by `test/core/design/contrast_test.dart`.

### Color — accent + semantic

| Token | Light / Dark | Use |
|---|---|---|
| `accent` (`colorScheme.primary`) | `#FF8C7A` / `#FF9F8C` | Primary action — warm coral |
| `success` (`wp.success`) | `#7DBA8A` / `#9ED1A8` | Positive — sage green |
| `danger` (`wp.danger`) | `#E07A5F` / `#F09781` | Destructive fills — terracotta (text uses `dangerText`) |
| `warning` (`wp.warning`) | `#F2CC8F` / `#F2D9A1` | Caution — butter yellow |

### Color — category palette (for category/tag/illustration variety)

Exposed on `WarmPlayfulExtensions`. Access via `Theme.of(context).extension<WarmPlayfulExtensions>()!`.

| Name | Light | Dark | Use |
|---|---|---|---|
| `wp.peach` | `#FBC4AB` | `#E89E84` | Default category |
| `wp.sage` | `#B5C9A1` | `#94AC81` | Calm / nature |
| `wp.butter` | `#FFE7A0` | `#E0C880` | Energy / warmth |
| `wp.lavender` | `#D6CDEA` | `#B5ABD0` | Reflection / journal |
| `wp.sky` | `#B8DCE5` | `#92BCC7` | Cool / clarity |

Container roles (`test/core/design/container_roles_test.dart`): `primaryContainer` = peach (own chat bubble), `tertiaryContainer` = sage, `errorContainer` `#F9D9CF` / `#5A2E24`, `secondaryContainer` = `surface` (tonal button). Snackbars are floating, `md` radius, on `inverseSurface` (brown on light, cream on dark). The default `Badge` is `error`/`onError` (brick `#A84A35` in light, so the Requests-tab badge is a deeper brick than terracotta).

`wp.categoryPalette` is a `List<Color>` for index-based assignment (e.g. `palette[habit.colorIndex % 5]`).

Use these for: habit category colors, tag chips, empty-state illustrations, onboarding scenes.

## Typography

- **Body**: Nunito — rounded geometric sans, very readable, friendly. Bundled as an asset (`assets/fonts/Nunito-{Regular,Medium,Bold,ExtraBold}.ttf`, weights 400/500/700/800, SIL OFL 1.1 — licence in `assets/fonts/OFL.txt` and the in-app Licences page). Applied to every text style via `ThemeData(fontFamily:)`; nothing is downloaded at runtime.
- **Display**: same family, just heavier weights (700/800).
- **Mono**: JetBrains Mono if you need it (numbers in stats), but most screens skip it.

| Style | Material slot | Size / Line | Weight |
|---|---|---|---|
| `display` | `displayLarge`, `displayMedium` | 32 / 42 | 800 |
| `h1` | `headlineLarge`, `headlineMedium` | 24 / 32 | 700 |
| `h2` | `titleLarge`, `titleMedium` | 18 / 26 | 700 |
| `body` | `bodyLarge`, `bodyMedium` | 16 / 26 | 500 |
| `caption` | `bodySmall`, `labelMedium` | 13 / 19 | 500 |
| `button` | `labelLarge` | 16 / 26 | 700 |

Body is `w500` (not `w400`). Nunito at 400 reads slightly anemic at body size; 500 sits perfectly.

Guarded by `test/core/design/typography_test.dart`: every text style carries Nunito, each pubspec entry maps its file to its weight, `google_fonts` is gone, the OFL is registered in `bootstrap()`.

## Spacing

Same scale as Notion: `4, 8, 12, 16, 24, 32, 48, 64`. Use `WarmPlayfulSpacing.sN` constants from `tokens.dart`.

## Radius — the signature

| Token | Value | Use |
|---|---|---|
| `WarmPlayfulRadius.sm` | 12 | Inputs, small chips |
| `WarmPlayfulRadius.md` | 16 | Buttons, list rows |
| `WarmPlayfulRadius.lg` | 24 | Cards, modals |
| `WarmPlayfulRadius.xl` | 32 | Hero cards, primary-action sheets |
| `WarmPlayfulRadius.pill` | 999 | Avatars, pills |

**Discipline:** every container should have a radius. Square corners look out of place in this system.

## Motion

Spring physics with gentle overshoot. Flutter recipes:

```dart
// 1. Built-in spring — drive an AnimationController with SpringSimulation.
final spring = SpringDescription(
  mass: WarmPlayfulMotion.springMass,
  stiffness: WarmPlayfulMotion.springStiffness,
  damping: WarmPlayfulMotion.springDamping,
);
controller.animateWith(SpringSimulation(spring, 0, 1, 0));

// 2. Implicit animation — pair `normal` with the back-out easing curve.
AnimatedContainer(
  duration: WarmPlayfulMotion.normal,
  curve: WarmPlayfulMotion.easing,
  ...
);

// 3. flutter_animate — spring scale on press.
.animate(target: pressed ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(0.96, 0.96), curve: WarmPlayfulMotion.easing)
```

Durations:
- `fast: 200ms` — instant feedback
- `normal: 350ms` — most transitions
- `slow: 500ms` — substantial state changes (sheet open, screen push)

Lottie animations (via `lottie` package) are welcome here. Empty states with a small Lottie illustration are signature.

## Iconography

- **Line icons** — `lucide_icons` package, default stroke (already on the heavier end, matches Nunito's weight).
- **Custom illustrations** are encouraged for onboarding + empty states. Soft pastels, rounded shapes, no thin lines.
- **Emoji is fine** — even encouraged for category icons and friendly touches (a 🌱 next to "Start a habit" empty state, etc.).

## Component primitives

Each example uses tokens from `tokens.dart` and the theme extension.

### `Card`

Soft container, radius `lg` (24), `surface` bg, no border. It is separated from the page by a soft shadow (`WarmPlayfulElevation.card` = 2, `wp.shadow`, transparent surface tint), not by the colour step alone. `CardThemeData` in `theme.dart` configures this for `Card`; a `Material` card (list rows, restaurant cards, inbox tiles) sets `elevation: WarmPlayfulElevation.card`, `shadowColor: wp.shadow`, `surfaceTintColor: Colors.transparent` itself. Chat bubbles and the add-photo tile are deliberately flat. `card_separation_test.dart` guards the theme and the card files. The `Container` recipe below is the older equivalent (do not use it for new cards):

```dart
Container(
  padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0F3D2E1F), // text @ 6%
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
  ),
  child: child,
);
```

Or the Material primitive:

```dart
Card(
  // shape, color, elevation come from CardThemeData
  child: Padding(
    padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
    child: child,
  ),
);
```

### `Pill`

Rounded full, surface bg, body text, padding-x 12. Used for tags, filter chips, category labels. Use `ChoiceChip` with the pill shape from theme:

```dart
ChoiceChip(
  label: const Text('🌱 health'),
  selected: selected,
  onSelected: onSelected,
  // shape (pill radius), backgrounds, label style all from ChipThemeData
);
```

For a non-interactive label, a plain `Container` with `BorderRadius.circular(WarmPlayfulRadius.pill)` works.

### `Button`

Hierarchy (min height 48 = `WarmPlayfulSize.minTap`; 56 = `actionHeight` for primary/tonal through `AppButton`; radius `md` = 16, horizontal padding `s5`, label `labelLarge` 700):

- **Primary** — `FilledButton`: coral `accent` fill, `onAccent` (brown) label; disabled = `border` fill, `subtle` label. Use it through `AppButton` (below), which keeps the coral fill while loading.
- **Secondary (tonal)** — `FilledButton.tonal`: `surface` fill (`secondaryContainer`), `text` label (used by `ErrorState`'s Try again; the other shipped secondary actions are outlined).
- **Outlined** — `OutlinedButton`: `text` label, 1.5px `muted` outline (3:1 against the page).
- **Ghost** — `TextButton`: transparent, `text` label.
- `ElevatedButton`, FAB, the selected nav-bar icon, the selected segmented button and the selected choice chip all use coral + `onAccent`.
- Switch: off = `muted` thumb and outline on the surface track; on = `onAccent` thumb on the coral track. Unselected SegmentedButton segments have a `muted` outline; the selected choice-chip checkmark is `onAccent`.
- Destructive text ("Deny", delete) uses `wp.dangerText`.

#### `AppButton` (`lib/core/design/widgets/app_button.dart`)

The one button for screens (do not hand-roll `FilledButton` + spinner). `AppButton(label:, onPressed:, variant:, isLoading:, loadingLabel:, icon:, expand:)`.

- Variants: `primary` (coral, 56 high), `tonal` (surface fill, 56 high), `outlined` and `text` (48 high = `minTap`). `expand: true` (default) is full width and needs a bounded-width parent; use `expand: false` inside a `Row`.
- Loading: tap handler is dropped (taps swallowed) but the enabled colours are kept (no grey fill); a `WarmPlayfulSize.spinner` (20) spinner in the foreground colour replaces the icon and `loadingLabel` (default `label`) replaces the text. Idle and loading content sit in an `IndexedStack`, so the button never changes size between the two (also at 2.0x text). While loading it is one disabled-button semantics node, announced as a live region with the loading label.
- Behaviour pinned by `test/core/design/widgets/app_button_test.dart` (variants, sizes, loading look, tap swallow, size stability, 2.0x/320 px, semantics); spinner contrast (>= 3:1) by `button_theme_test.dart`, `meal_detail_button_test.dart`, `report_sheet_test.dart`.

Contrast and states are pinned by `test/core/design/button_theme_test.dart`. (The earlier "scale 0.96 on press" spring is not implemented.)

### `ListRow`

Surface bg, radius `md`, padding 16. Avatar/icon left, title + caption middle, action right.

```dart
Material(
  color: Theme.of(context).colorScheme.surface,
  borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
  child: InkWell(
    borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
      child: Row(children: [leading, ..., trailing]),
    ),
  ),
);
```

Use a `Divider` between rows (uses `dividerColor` from theme).

### `EmptyState`, `ErrorState`, `SkeletonCard` (loading / empty / error)

Every `AsyncValue` feed renders all three: a skeleton while loading, `EmptyState` for "nothing here", `ErrorState` for a failed load. Tokens only (`WarmPlayfulSize.stateIcon` 48, `WarmPlayfulSkeleton.*`).

- **`EmptyState`** (`lib/core/design/widgets/empty_state.dart`): centred, optional icon (muted, hidden from semantics), `titleMedium` title, optional body, optional action (usually an `AppButton`). Always scrollable (a parent `RefreshIndicator` keeps working) and safe at 2.0x text. Title and body use `wp.muted`.
- **`ErrorState`** (`error_state.dart`): `EmptyState` with a `cloud_off` icon, default "Couldn't load this" / "Check your connection and try again." and a tonal **Try again** `AppButton` that calls `onRetry`. The title keeps the normal title colour (only the body and icon are muted); title and message are one live region, so a screen reader announces it when it replaces a skeleton. Feeds pass `onRetry: () => ref.invalidate(...)`, except restaurant search (re-runs the typed query) and Discover (runs its pull-to-refresh, which also re-reads the location).
- **`SkeletonCard`** (`skeleton_card.dart`): surface card with an optional avatar block and `lines` text blocks (`wp.border`), the last one shorter; a shimmer sweep (`WarmPlayfulSkeleton.shimmer`) in a colour lighter than the blocks in both modes (`wp.divider` in light, `wp.subtle` in dark). `SkeletonList` stacks them with the feed padding (not scrollable, clips rather than overflows) and `SkeletonMessages` shows alternating bubbles for the chat. With `MediaQuery.disableAnimations` the shimmer is off and the skeleton is static. `SkeletonList`/`SkeletonMessages` are announced as "Loading" (live region); the cards themselves are hidden from semantics.

Tested: `test/core/design/widgets/{empty_state,error_state,skeleton_card}_test.dart` (render, retry callback, semantics/live region, light and dark colours, 2.0x text at 320 px, shimmer on/off, highlight lighter than the blocks) plus the feed screen tests (skeleton while loading, Try again re-subscribes). Skeleton tests must `pump(Duration)`, never `pumpAndSettle` (see `MASTER-SPEC.md` gotcha 6).

### `Sheet`

Bottom sheet, radius `xl` (32) top corners only, surface bg, drag handle at top. Use `showModalBottomSheet` — the theme already configures shape/handle:

```dart
showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  // backgroundColor + shape (top radius xl) + drag handle come from BottomSheetThemeData
  builder: (ctx) => Padding(
    padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
    child: child,
  ),
);
```

For full control over the shape on a custom sheet:

```dart
ClipRRect(
  borderRadius: const BorderRadius.vertical(
    top: Radius.circular(WarmPlayfulRadius.xl),
  ),
  child: Container(
    color: Theme.of(context).colorScheme.surface,
    child: child,
  ),
);
```

#### Report, rating and block sheets (UX plan 18)

Sheets and dialogs name who they are about so a person never has to remember which profile they came from. Widget-tested.

- **Report** (`showReportSheet`): title "Report <name>" (user targets; the name is read from the already-loaded public profile at action time), "Report this meal" for meal targets, plain "Report" when the name is not loaded. The note field has a visible 1 px `wp.muted` edge (`sheetFieldBorder`, a local decoration, not a theme change; >= 3:1 against the sheet) and a `done` keyboard action. The selected reason chip label uses `wp.onAccent` (the chip theme's default measured 2.5:1 light / 1.7:1 dark on coral).
- **Rating** (`showRatingSheet`): title "How was your meal with <name>?" (plain fallback). Stars: unselected = outline in `wp.muted`, selected = filled in `onSurface` (the sage tertiary is only 1.9:1 on the sheet; state is shape plus 10:1 colour). The comment field gets the same visible edge. Both sheets scroll with the keyboard open.
- **Block dialog** ("Block <name>?", fallback "Block this person?"): the confirm button is in `wp.dangerText`; Cancel stays neutral.
- **Safety tips sheet** (`showSafetyTipsSheet`, key `safety_tips_sheet`): the same four tips as `/settings/safety` (`SafetyTipsList`), scrollable, with a "Got it" button.

## Auth and onboarding patterns (UX plan 17a)

Sign-in, phone code, age gate and profile setup. All widget-tested unless noted; what only the capture shows is listed in `docs/ux/17a-verification.md`.

**Inline field errors.** A problem with what the user typed is shown ON the field (`InputDecoration.errorText`, `wp.dangerText`, `errorMaxLines: 3`), never as a separate sentence under the button, and never costs a round trip: the sign-in phone number is checked locally (`isPlausiblePhone`, `+` and 8-15 digits) and the field is refocused so the keyboard scroll brings the error and the button into view. A wrong SMS code (`InvalidSmsCodeException`, mapped in the repository) shows "That code didn't work. Check it or resend." on the code field, clears it and refocuses it; the message clears as soon as the user types. Failures the user cannot fix by editing a field (SMS could not be sent, timeout, network) use one generic sentence, "Something went wrong — please try again.", in `colorScheme.error`, in a `liveRegion` + `container` `Semantics` so a screen reader announces it when it appears.

**Waiting states.** Phone sign-in holds the "Sending code…" spinner (`AppButton.isLoading`) until `codeSent` / `onError` fires, with a 60 s safety timeout that falls back to the generic error. While one sign-in method is in flight the other two are disabled. The 6th code digit submits by itself (the Verify button stays as the fallback); after a success the button stays in its "Verifying…" state so the used code cannot be sent twice.

**Resend countdown.** The code screen's text-variant `AppButton` reads "Resend code in 29 s" and is disabled until a 30 s deadline passes (`package:clock`, derived from the deadline, so time spent in the Messages app counts); it then reads "Resend code", shows "Sending code…" while it works (60 s timeout) and confirms with a muted live-region line "Code sent again" while the countdown restarts. A failed resend shows the generic sentence and keeps the typed code. "Change" (next to the number, 48 pt tall, spoken as "Change phone number") and the app bar's back arrow return to the sign-in screen.

**Under-18 notice.** An under-18 date of birth signs the user out and the sign-in screen shows a dismissible peach card ("You must be 18 or older to use Convyve.", `wp.peach`, live region, 48 x 48 close button with a "Dismiss" tooltip). The age gate sets `underageNoticeProvider` BEFORE it signs out (the age gate is unmounted by then); starting any sign-in or dismissing clears it. If `signOut` fails the flag is reset (the user is still signed in), and an adult submission clears a stale flag before writing. The "blocked" layout in `AgeGateScreen` is a fallback no frame ever shows.

**Official provider buttons.** Apple: `SignInWithAppleButton` from `sign_in_with_apple` (black on the light theme, white on the dark one, 56 high, radius `md`, "Continue with Apple", text scale capped at 1x because the label is 0.43 x height); it has no loading state, so while any method is in flight it is dimmed and inert (never a `null` handler: that swaps the brand colours for Cupertino grey), and while Apple itself is in flight it is one disabled "Signing in…" live-region node. Google: an outlined `AppButton` with the Material `g_mobiledata_rounded` icon is a stand-in; Google's brand rules want the multicolour "G" asset (open item, see `docs/ux/17a-verification.md`).

**Scrolling forms.** The age gate and profile setup scroll (`SingleChildScrollView`; the age gate stays centred when it fits) and the code screen scrolls too, so large text or the keyboard never hides a button. Text fields that sit above other controls give the keyboard-scroll room for them (`scrollPadding` bottom = `WarmPlayfulSize.keyboardReveal` = 3 x `actionHeight`: the sign-in phone field, the code field, and the profile form's `kProfileFieldScrollPadding`). At 2.0x text on a 568 pt phone with the keyboard up the code screen's error line still fits above the keyboard but Verify may not (the 6th digit submits, so it is not needed). Typing in Bio with the keyboard up also scrolls Continue into view (`Scrollable.ensureVisible`, keep-visible-at-end), because `scrollPadding` only guesses how far below the caret the button is. The age-gate date picker opens on the year grid with the help text "Your date of birth".

**Profile setup.** Subtitle "Name, photo and gender. That's it." The add-photo tile shows "Add photo" under the icon (icon and label in `onSurface`, outline `wp.muted`, label scaled down with `FittedBox(BoxFit.scaleDown)` instead of overflowing the fixed grid cell; spoken as "Add photo" or, while uploading, "Uploading photo"). The remove button is an `IconButton` with `tooltip: 'Remove photo'` (the tooltip is also its accessible name): 48 x 48 hit area, 24 visual badge in the thumbnail's top-right corner. Continue is disabled until photo, name and gender are set, and a muted live-region line under it names what is missing ("Still needed: a photo, your name and how you identify.", only the remaining items once some are done; hidden when valid).

---

## Discover, meal detail, create meal (UX plan 17b)

Widget-tested unless noted; what only the capture shows is listed in `docs/ux/17b-verification.md`.

### Meal-detail action bar (`MealActionBar`, `lib/features/meal/presentation/widgets/meal_action_bar.dart`)

The request button is pinned: it is `Scaffold.bottomNavigationBar` (a `Material` with card elevation inside a `SafeArea`, padding `s4`), so it never scrolls away under a long page. One full-width `AppButton` (up to two lines) plus a status line below it. The bar has ONE height in every state at a given text size and width: `_Layout` measures every label the button can show ("Request to join", "Sending request…", "Requested", "Open chat" with its icon, "Not selected", "Meal cancelled", "This is your meal", "Women only", "Try again") with the bar's text scaler and the width left inside a button, takes the largest line count (1 or 2), and sizes the action slot once as `max(WarmPlayfulSize.actionHeight, lines x label line height + 2 x s3)` for every state, the loading skeleton included (a button grows to the slot, the skeleton fills it). The status slot is always the same height too (empty when there is no status). Text scale INSIDE the bar is clamped to 2.0 (`MediaQuery.withClampedTextScaling`, the app's tested ceiling), so the main action honours large text: on 320 x 568 the bar is 83 px at 1.0x, 91 px at 1.3x and 212 px at 2.0x, which leaves the scroll body 397 / 389 / 268 px (widget-tested). Why a shared height: a bar that changes height from state to state shifts the whole page when a request resolves. The status line is one line up to 1.3x and may use two lines above it (both reserved in every state), with an ellipsis if it needs more; its full text is the `Semantics` label (a `liveRegion` + `container` node mounted in every state, so a status that appears is announced and VoiceOver reads the whole sentence even when it is cut on screen).

| Viewer state | Button (key) | Status line |
|---|---|---|
| Own meal | "This is your meal", tonal, disabled (`meal_detail_your_meal_button`) | "See requests in the Requests tab." |
| Women-only meal, viewer not a woman | "Women only", tonal, disabled (`meal_detail_women_only_disabled_button`) | "Only women can join this meal." (`meal_detail_women_only_note`) |
| Request state loading | Skeleton, action height (`meal_action_skeleton`) | none |
| Request state failed to load | "Try again", tonal button (`meal_detail_request_retry_button`) re-reads the state | "Couldn't load your request." in `wp.dangerText` |
| No request yet | "Request to join", primary (`meal_detail_request_to_join_button`); "Sending request…" with a spinner while the write is in flight | none |
| Pending | "Requested", tonal, disabled (`meal_detail_requested_button`) | "Waiting for the host to reply." |
| Approved | "Open chat" with a chat icon, primary, enabled, opens `/chats/{mealId}` (`meal_detail_matched_banner`: the key of the old banner, kept so E2E and the capture still find it) | "You're matched. Say hi!" |
| Denied | "Not selected", tonal, disabled (`meal_detail_not_selected_button`) | "The host chose someone else." |
| Meal cancelled (any viewer but the host) | "Meal cancelled", tonal, disabled (`meal_detail_cancelled_button`); checked after "own meal" (the host keeps "This is your meal") and before the women-only and request branches | "The host cancelled this meal." (also used when the host deleted their account). The meal arrives as a static snapshot through the route `extra`, so a meal cancelled while the screen is already open updates only on the next open (live meal stream is a follow-up) |

The bar is also the always-mounted home of the failed-request snackbar. Latency compensation swaps "Request to join" for "Requested" before the server answers, so a listener on the button would be gone when a rejection arrives; the bar listens to the create-request controller (loading to error only) and shows "Couldn't send your request. Try again.". `createRequest` wraps every failure in `RepositoryWriteException`, so the specific "This meal is no longer open." copy (which the code already maps from `MealNoLongerOpenException`) never shows in production yet (follow-up: the repository must rethrow it). The widget test for the equal height in all states runs at 1.0x, 1.3x and 2.0x text on 320 x 568 (no overflow, no label ellipsized or clipped, scroll body at least 220 px).

### Discover (`DiscoveryScreen`)

**Card** (`_MealCard`, `Material` surface, radius `lg`, padding `s4`, tappable), top to bottom:
1. Restaurant name (`bodyMedium`, h2 weight, at most 2 lines with an ellipsis) and, for a woman viewer on a women-only meal, the peach "Women only" badge, in a `Wrap` so at large text the badge drops under the name instead of overflowing.
2. ONE muted line `<when> · <distance>` (e.g. `Today 20:30 · 1.2 km`, `formatMealDateTime`), at most two lines (at large text the distance wraps instead of being cut off). It used to be two chips that overflowed at xxl.
3. Host row: 32 pt avatar (photo or person icon) + display name (one line, ellipsis), fallback "Host".

The list has bottom padding of `actionHeight + s8` so the extended "Create a meal" FAB never covers the last card (shot `23b_discover_scrolled_end`). The FAB is the entry to `/meals/new` (hidden for an empty feed, where the empty state has its own button, so there is never a second "Create a meal"); sign-out lives in Settings (with a confirm dialog), not in the Discover app bar.

**Empty state:** no meals nearby = `EmptyState` (restaurant icon, "No meals nearby yet", "Be the first: host a meal and someone will join.") with a "Create a meal" `AppButton` (`discovery_empty_create_button`), under the Paris notice. Loading (`SkeletonList`) and error (`ErrorState`, Try again re-reads the location like a pull-to-refresh) also keep the notice above them; the FAB stays in the loading and error states. Pull-to-refresh works in the empty and error states (not while the loading skeleton shows).

**Paris notice** (`ParisNotice`): "Convyve is Paris-only for now — we're just getting started here." with a 48 x 48 close button (tooltip "Dismiss"). In the data state it is the FIRST ITEM of the list, so it scrolls away with the cards instead of eating screen space; in the loading, empty and error states it sits above the state widget. Dismissal is PER SESSION only (state of `_DiscoveryScreenState`): it comes back at the next launch. Persisting it needs `shared_preferences`, which is not a dependency; adding one is a later decision, not part of 17b.

### Create a meal and restaurant search

**Default time.** The date/time field opens the pickers on `nextMealSlot(now)`: now + 1 hour rounded UP to the next :00 or :30 (`12:29` gives `13:30`, `12:31` gives `14:00`, leftover seconds push to the next slot, midnight rolls over), never "11:01". The field itself still starts as "Pick date & time" and Create meal stays disabled until the user confirms a time. The time picker is 24 h (`alwaysUse24HourFormat`), like every time the app shows. A pick less than `mealMinLead` (5 minutes) from now is refused with "Pick a time at least 5 minutes from now.". The note field gives keyboard scrolling `WarmPlayfulSize.keyboardReveal` of room (`scrollPadding`), so Create meal can be reached with the keyboard up at 2x text on 320 x 568. After creating, the snackbar reads "Meal posted. You'll get requests in the Requests tab." (was "Meal created!").

**Search copy.** With the untouched field the screen shows the default restaurant list; if that is empty it says "No restaurants to show yet.". A typed query without results says "No restaurant called “<query>”. Try another name." (the query the results answer, not the live text; padded `s4` so a long query wraps inside the margins).

---

## Requests, chat and profile (UX plan 18)

Widget-tested unless noted; what only the capture shows is in `docs/ux/18-verification.md`.

### Request inbox (`RequestInboxTile`)

- **Actions.** Approve = `AppButton` primary (coral, 56 high; "Approving…" with a spinner while in flight); Deny = `AppButton` text variant in `wp.dangerText` (>= 4.5:1 in both modes; "Denying…"). Both live in an `OverflowBar(alignment: end, overflowAlignment: end, overflowDirection: up)`: side by side when they fit, stacked with Approve on top at narrow widths / large text (no overflow at 320 px, 2.0x; both >= 48 high). Past-meal requests keep Approve disabled (a tooltip and a semantics hint say "Meal time has passed") and Deny enabled.
- **Busy state is per request.** `inboxPendingProvider` (a keep-alive map `requestId -> InboxAction`, set before the await and cleared in `finally`) decides which tile is busy: both buttons of THAT tile disable and the pressed one shows the spinner; other tiles stay usable and two concurrent actions do not clobber each other. The 5 snackbar outcomes and the unmount-mid-flight handling are unchanged.
- **Guest rating.** `RatingBadge(uid: guestId)` under the guest name.
- **Tab icon.** Requests tab = `Icons.inbox_outlined` / `Icons.inbox` with the count `Badge` (the old "unread dot" mail icon is gone).

### Chat anatomy (`ChatScreen`, top to bottom)

1. App bar: title, "Can't make it" (meal cancel / withdraw), safety menu.
2. **Meal header** (`ChatMealHeader`, key `chat_meal_header`): one row (min 48), "Restaurant · Tue 6 Oct, 20:30" in muted `bodyMedium`, ellipsis, chevron; tap pushes the meal detail. Nothing while the meal loads or is missing.
3. **Safety banner** (`SafetyTipsBanner`, key `safety_tips_banner`): one line "Meeting up? Safety tips", tap opens the safety sheet, an X ("Dismiss safety tips", 48 dp) hides it for the session. It is a banner, not a `Card`, so it never competes with the messages (the old tips card took up to 40% of the screen).
4. Message list (the only flexible child): **day separators** ("Today", "Yesterday", "Mon 5 Oct", with the year when it differs; `formatDayLabel`) and bubbles grouped into runs: a time only under the last bubble of a run, gap `s3` after a run and `s1` inside it.
5. **Post-meal card** (`PostMealCard`, key `post_meal_card`) is a list item, so it scrolls with the messages instead of being pinned: just above the composer, or above the oldest message on a short viewport (< 2 x `keyboardReveal`), or above "Say hi" in an empty thread (decided only while the keyboard is closed, so opening the keyboard never moves it). It is `Offstage` while the keyboard is open (state survives, `post_meal_prompt_shown` fires once). Layout: a Row 3:2 (text : "Rate <name>" button) up to text scale 1.3, a Column with a full-width button above it; 108 px tall at 320 px / 1.0x, 266 px at 2.0x.
6. Composer: clears the moment you send and restores the text if the send fails. Hidden when the messages fail to load (an `ErrorState` with retry is the only content) and in the "no longer available" state.

The header and banner step aside while the keyboard is open. The Chats list rows add a meal line ("Restaurant · date") under the name, an `Unread` semantics label on the dot, and the empty state is "No chats yet" with a "Find a meal" button.

### Profile (`ProfileEditScreen`, the Profile tab)

Title "Profile"; "Your rating" + `RatingBadge`, or "No ratings yet", wrapping at large text. **Save is enabled only while the (trimmed) name, bio or gender differ from the saved profile AND the form is valid.** Photos are excluded from that comparison: add/remove write straight to the profile and never wait for Save. When the form is invalid (blank name, no photo) a muted live-region line under Save says "Still needed: <missing fields>."; an unchanged but valid form shows no hint. A cleared bio is sent as an empty string (null would mean "leave unchanged"). Success: "Profile saved" snackbar, stay on the screen, Save disabled again. Failure: the form and typed text stay, the error shows, Save stays enabled for a retry.

## Date and time formats

English, 24-hour clock, day before month, always in the viewer's LOCAL time (`lib/core/util/date_format.dart`, pure, dependency-free; `intl` and French arrive with plan 19, which replaces the internals, not the call sites):

| Function | Output |
|---|---|
| `formatMealDateTime(v, {now})` | `Today 20:30`, `Tomorrow 12:30`, otherwise `Sat 10 Oct, 20:00` (`Sat 10 Oct 2027, 20:00` when the year differs from today's). Past dates use the absolute form. |
| `formatClockTime(v)` | `20:30` (chat timestamps) |
| `formatMonthDay(v)` | `5 Jan` |
| `formatLongDate(v)` | `5 January 2027`; pass a local calendar date (a UTC-midnight date-only value shows the previous day behind UTC) |

"Today"/"Tomorrow" compare local calendar days (DST-safe). Unit-tested in UTC and re-run under `TZ=Pacific/Kiritimati` in CI so a UTC-vs-local mistake cannot pass vacuously.

## Router contract

`routerProvider` (`lib/core/routing/router.dart`) builds ONE `GoRouter` per provider lifetime. It used to be rebuilt on every `users/{uid}` write, which reset navigation to Discover and dropped form state (audit X-09, e.g. adding a profile photo). Now only a change of the signed-in uid (sign-in/sign-out), or a flip of `ageVerified` or `profileComplete` (selected values, `ref.listen`) bumps `refreshListenable`, which re-runs `redirect` against the current location; other user-doc fields (photos, name, bio, ratings) never touch the router. Consequences: routes are fixed at startup (hot reload does not pick up route changes: hot restart); never `ref.watch` the user doc to build the router. A direct switch from one signed-in user to another (Android phone auto-verification, no signed-out state) calls `router.go('/discover')`, dropping the first user's pushed routes. A sign-out immediately followed by a sign-in with no frame in between is only possible in tests (see the E2E caveat in `TEST-PLAN.md`). Covered by `test/core/routing/router_stability_test.dart` and `redirect_test.dart` (widget level; the profile-photo case is only seen end-to-end in the UX capture note in `docs/ux/16b-verification.md`).

---

## Screen specs

Added via `/design`.

### Chat — "Can't make it" action

**Screen:** Chat (`/chats/:matchId`) app bar. No new screen or route.
**Purpose:** Let the host or guest of a matched, future meal withdraw cleanly. PRD: "Can't make it - cancel or withdraw from a matched meal". Analytics: `meal_cancelled`.

**Layout:** a trailing `IconButton` (Material `Icons.event_busy_outlined`, tooltip "Can't make it") in the app bar `actions`, left of the existing safety menu. Tap opens an `AlertDialog`:
- Title: host "Cancel this meal?" / guest "Withdraw from this meal?"
- Body: host "<name> will be told and the meal will be removed." / guest "<name> will be told and the meal will open up again for others."
- Actions: `TextButton` "Keep meal" (default/dismiss) and a destructive `TextButton` "Cancel meal" / "Withdraw" (`colorScheme.error` label, matching the Delete-account dialog).

**Widgets:** reused `IconButton`, `AlertDialog`, `ScaffoldMessenger` snackbar; no new tokens.

**States**
- Hidden: meal not `matched`, time passed, or the meal is still loading/missing.
- Confirming: dialog above. While the callable runs the destructive button shows a small spinner and is disabled (same pattern as other in-flight buttons); dialog cannot be dismissed by tapping outside.
- Success: dialog closes, snackbar "Meal cancelled." / "You've withdrawn.", navigate to `/chats`.
- Error/offline: dialog closes, snackbar "Couldn't cancel. Check your connection and try again."; chat unchanged.
- Dark mode and large text: theme colors only; the dialog wraps at 2.0x and scrolls if needed.

**Accessibility:** icon button has `tooltip` (read by screen readers) as "Can't make it", >= 48dp; dialog title is announced; destructive action is a text label, not color alone.

---

### Meal detail — "Open in Maps" action

**Screen:** Meal detail (restaurant card addition). No new screen.
**Purpose:** One-tap hand-off from the meal's restaurant to the user's own maps app, so a guest can find the venue on the day. Link-out only; no embedded map (post-MVP). PRD: "Open restaurant in Maps (meal detail)". Analytics: `directions_opened`.
**Route:** Existing meal detail route (unchanged); opens an external app, no in-app navigation.

**Layout (top→bottom)** — inside the existing `meal_detail_restaurant_card` (`Material`, `surfaceContainerHighest`, radius `lg`, padding `s4`):
1. Restaurant name row (+ women-only badge) — unchanged
2. Address (`bodyMedium`, `wp.muted`) — unchanged
3. `SizedBox(height: s3)`
4. **Open in Maps** — left-aligned, intrinsic width (not full width): map-pin icon (Material `Icons.place_outlined`, matching the icons used across the app today; button-theme default size) + label "Open in Maps"

**Widgets**
- Reused: existing restaurant card, `OutlinedButton.icon` (Outlined variant per DESIGN.md § Button — secondary action, so it never competes with the screen's primary action), `ScaffoldMessenger` snackbar.
- New: none. No new tokens (min height `WarmPlayfulSize.minTap`, radius `md`, gaps `s3`/`s2`, colors from the button theme).
- Placement stays inside the card so the address and its action read as one unit; `Wrap`-free `Align(alignment: centerStart)`.

**States**
- Filled: button visible as above (outline `muted` 1.5px, `text` label; same in dark mode via theme).
- Empty (no usable coordinates — missing or 0,0, e.g. legacy meals): action not rendered, no gap left behind (the `SizedBox` is part of the conditional); card shows name + address exactly as today.
- Loading: none — the hand-off is local; the button is tappable immediately. A rapid double tap is ignored while a launch is in flight (guard flag), no spinner.
- Offline: unchanged behavior — still launches the maps app (no connectivity check in Convyve; the maps app handles its own offline state).
- Error (no app can handle the URL / launch returns false or throws): snackbar "Couldn't open Maps"; card and screen state unchanged; button stays enabled for retry.
- Dark mode: parity from the theme (no hard-coded colors); verify outline/label contrast against `surfaceContainerHighest` dark.

**Interactions**
- Tap → fire `track(const DirectionsOpened())` → launch the external maps app at restaurant `lat/lng` labeled with the restaurant name (`url_launcher`, `LaunchMode.externalApplication`): iOS `https://maps.apple.com/?ll=<lat>,<lng>&q=<name>`; Android `geo:<lat>,<lng>?q=<lat>,<lng>(<name>)`, falling back to `https://www.google.com/maps/search/?api=1&query=<lat>,<lng>`. URL-encode the name. No API key.
- The event fires on tap (intent), before the launch result is known; a failed launch still shows the snackbar.

**Accessibility**
- `Semantics(button: true, label: 'Open ${restaurant.name} in Maps')` wrapping the button; the visible text "Open in Maps" is excluded from the semantics tree to avoid double announcement (`ExcludeSemantics` on the label).
- Target ≥ 48dp (theme `minTap`); at large text scales the label wraps within the button and the button grows in height, never clips or truncates (no fixed height).
- Icon is decorative (`excludeFromSemantics`).
- Snackbar text announced as a live region by default (`SnackBar`).

**Tests to write (via `/test`):** hidden for 0,0 / missing coords; visible otherwise; tap fires `directions_opened` once and calls the injected launcher with the expected URL per platform; launcher failure shows "Couldn't open Maps"; semantics label present; large text scale (2.0) renders without overflow; dark theme golden-free contrast assertion on the button theme.

---

## Settings and Blocked people (UX plan 18)

Settings is one `ListView` of grouped rows (`Settings`, widget-tested in `settings_screen_test.dart`). Group titles are small headers (`Semantics(header: true)`), navigating rows carry a trailing `chevron_right_rounded`, every row is >= 48 high.

| Group | Rows (key) | Notes |
|---|---|---|
| Account | Edit profile (`settings_edit_profile`, `go('/profile')`), Phone number (read-only, only when the sign-in has one), Sign out (`settings_sign_out`) | Sign out confirms first |
| Safety | Blocked people (`/settings/blocked`), Safety tips (`/settings/safety`), Contact support (email) | |
| Notifications | "Notification settings", subtitle "Manage notifications in iOS Settings" (`settings_notifications`) | iOS only (`defaultTargetPlatform`); hidden on Android |
| Legal | Privacy Policy, Terms of Service, Open-source licences (`showLicensePage` with app name and version) | |
| About | Version | |
| (after a Divider) | Delete account (`settings_delete_account`) | last in the list, `wp.dangerText` |

- Notification settings: one row, opens `app-settings:` through `url_launcher` (injectable `openAppSettingsProvider`). Shown only when `defaultTargetPlatform == iOS`; the Android row is later (it needs an Android settings intent, so a new package).
- Language switch: not here; it lands with French (plan 19).
- `/settings/blocked`: AppBar "Blocked people"; rows = avatar (initials fallback), name from the public profile ("Unknown user" if it is gone), outlined "Unblock" button (announced "Unblock <name>" by screen readers; "Unblocking…" while in flight) with a row-level spinner, plain snackbar "Unblocked <name>." (no undo, YAGNI); the button drops below the name at text scale > 1.3. Empty: block icon, "You haven't blocked anyone". Skeleton while loading, ErrorState with retry. Data: `BlockRepository.watchBlockedByMe` (query `pair array-contains uid`, `blockerUid == uid` filtered client-side, because the rules cannot prove a `blockerUid ==` query).
- `/settings/safety`: the same four tips as the chat sheet (`SafetyTipsList`).
