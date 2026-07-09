# Design System — Warm Playful

Soft pastel palette, rounded corners, gentle spring motion. The kind of design language that says "this app is for *you*, not your manager."

**Best for:** consumer apps, wellness, habit + journal, kids/family, meditation, food, anything where warmth beats efficiency.

**Platforms:** iOS, Android, web.

## Aesthetic principles

1. **Never pure white. Never pure black.** The bg is `#FFFAF3` (cream); dark mode bg is `#231811` (warm brown).
2. **Round more than feels right, then round more.** Buttons radius 16, cards 24. Sharp edges look hostile in this system.
3. **Color tells the story.** A 5-color accent palette (peach / sage / butter / lavender / sky) supplements the single accent. Use it for category tags, illustrations, empty states.
4. **Motion has a touch of bounce.** Spring physics, gentle overshoot. Never aggressive — `damping: 14`, not 8.
5. **Type carries weight.** Nunito 700/800 on titles. Friendly but confident.

## Tokens

Full reference: [`tokens.ts`](tokens.ts).

### Color — surfaces (never pure white/black)

| Token | Light | Dark |
|---|---|---|
| `bg` | `#FFFAF3` (cream) | `#231811` (warm dark) |
| `surface` | `#FFF1E6` (warm peach) | `#2E211A` |
| `border` | `#F0E2D2` | `#3F2F25` |
| `divider` | `#F7EBDD` | `#352720` |

### Color — text (warm browns, not grays)

| Token | Light | Dark |
|---|---|---|
| `text` | `#3D2E1F` | `#FAEBD7` |
| `muted` | `#8C7563` | `#B5A18C` |
| `subtle` | `#B5A18C` | `#8C7563` |

### Color — accent + semantic

| Token | Light / Dark | Use |
|---|---|---|
| `accent` | `#FF8C7A` / `#FF9F8C` | Primary action — warm coral |
| `success` | `#7DBA8A` / `#9ED1A8` | Positive — sage green |
| `danger` | `#E07A5F` / `#F09781` | Destructive — terracotta (warm, not aggressive) |
| `warning` | `#F2CC8F` / `#F2D9A1` | Caution — butter yellow |

### Color — accent palette (for category/tag/illustration variety)

| Name | Light | Dark | Use |
|---|---|---|---|
| `peach` | `#FBC4AB` | `#E89E84` | Default category |
| `sage` | `#B5C9A1` | `#94AC81` | Calm / nature |
| `butter` | `#FFE7A0` | `#E0C880` | Energy / warmth |
| `lavender` | `#D6CDEA` | `#B5ABD0` | Reflection / journal |
| `sky` | `#B8DCE5` | `#92BCC7` | Cool / clarity |

Use these for: habit category colors, tag chips, empty-state illustrations, onboarding scenes.

## Typography

- **Body**: Nunito — rounded geometric sans, very readable, friendly. Bundle via `expo-font` for iOS/Android.
- **Display**: same family, just heavier weights (700/800).
- **Mono**: JetBrains Mono if you need it (numbers in stats, code), but most screens skip it.

| Style | Size / Line | Weight | Use |
|---|---|---|---|
| `display` | 32 / 42 | 800 | Page titles |
| `h1` | 24 / 32 | 700 | Section headers |
| `h2` | 18 / 26 | 700 | Subsections |
| `body` | 16 / 26 | 500 | Default — medium weight, looser line |
| `caption` | 13 / 19 | 500 | Meta |

Body is `500` weight (not 400). Nunito at 400 reads slightly anemic at body size; 500 sits perfectly.

## Spacing

Same scale as Notion: `4, 8, 12, 16, 24, 32, 48, 64`.

## Radius — the signature

| Token | Value | Use |
|---|---|---|
| `sm` | 12 | Inputs, small chips |
| `md` | 16 | Buttons, list rows |
| `lg` | 24 | Cards, modals |
| `xl` | 32 | Hero cards, primary-action sheets |
| `pill` | 999 | Avatars, pills |

**Discipline:** every container should have a radius. Square corners look out of place in this system.

## Motion

Spring physics with gentle overshoot:
- `fast: 200ms` — instant feedback
- `normal: 350ms` — most transitions
- `slow: 500ms` — substantial state changes (sheet open, screen push)
- Reanimated: `withSpring(target, { damping: 14, stiffness: 180, mass: 1 })`
- CSS easing: `cubic-bezier(0.34, 1.56, 0.64, 1)` — gentle back-out

Lottie animations welcome here. Empty states with a small Lottie illustration are signature.

## Iconography

- **Line icons** — Lucide stroke 1.75 (slightly heavier than the other systems to match Nunito's weight).
- **Custom illustrations** are encouraged for onboarding + empty states. Soft pastels, rounded shapes, no thin lines.
- **Emoji is fine** — even encouraged for category icons and friendly touches (a 🌱 next to "Start a habit" empty state, etc.).

## Component primitives

### `Card`
Soft container, radius `lg` (24), surface bg, no border (the radius does the work), optional soft shadow (`shadow-color: #3D2E1F`, `shadow-opacity: 0.06`, `shadow-radius: 12`).

### `Pill`
Rounded full, surface bg, body text, padding-x 12. Used for tags, filter chips, category labels.

### `Button`
- **Primary**: `accent` bg, white text, radius `md` (16), padding-x 24, height 48. Press: scale 0.96 with spring.
- **Secondary**: `surface` bg, `text` color, same shape.
- **Ghost**: transparent bg, `text` color.

### `ListRow`
Surface bg, radius `md`, padding 16. Avatar/icon left, title + caption middle, action right. Divider is `divider` token, full-width minus padding.

### `EmptyState`
Centered column: Lottie or illustration (200×200 area), `display` text, body-muted subtitle, primary action button below. Always playful.

### `Sheet`
Bottom sheet, radius `xl` (32) top corners only, surface bg, drag handle at top (40×4 pill, `border` color).

## Screen specs

Added via `/design`.
