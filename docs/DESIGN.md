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
