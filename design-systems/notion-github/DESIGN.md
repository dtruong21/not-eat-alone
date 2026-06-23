# Design System — Notion + GitHub

A calm, document-feel design language built for productivity. Inspired by Notion's typography-driven hierarchy and GitHub's contribution-graph aesthetic.

**Best for:** tracker apps, productivity tools, anything data-dense where users live for hours.

**Platforms:** iOS, Android, web (NativeWind / Tailwind compatible).

## Aesthetic principles

1. **Hierarchy through typography, not boxes.** Notion rarely uses cards. We don't either.
2. **Monospace earns its place.** Numbers, dates, streak counts — monospace. Body text — not monospace.
3. **Heatmap is the icon.** When a screen needs visual identity, it gets a contribution-graph somewhere.
4. **Dark mode is first-class.** Every token has a dark value.
5. **Motion is functional.** Animate state changes — never decoration.

## Tokens

Full reference: [`tokens.ts`](tokens.ts). Highlights below.

### Color — surfaces

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#ffffff` | `#0d1117` | Page background |
| `surface` | `#f7f6f3` | `#161b22` | Cards, modals, raised areas. Notion warm gray + GitHub dark surface |
| `border` | `#e9e9e7` | `#30363d` | Hairlines |
| `divider` | `#ededec` | `#21262d` | Subtler than border, in-page section breaks |

### Color — text

| Token | Light | Dark |
|---|---|---|
| `text` | `#37352f` | `#e6edf3` |
| `muted` | `#787774` | `#7d8590` |
| `subtle` | `#9b9a97` | `#6e7681` |

### Color — accent + semantic

| Token | Value | Use |
|---|---|---|
| `accent` | `#2383e2` (light) / `#388bfd` (dark) | Primary action, links |
| `success` | `#26a641` / `#3fb950` | Positive state |
| `danger` | `#f85149` | Destructive action |
| `warning` | `#d29922` | Caution |

### Heatmap (GitHub canonical)

5-step scale for data-density visualizations. See `tokens.colors.<mode>.heatmap`.

## Typography

- **Body**: Inter, system fallback. Used everywhere by default.
- **Mono**: JetBrains Mono, `ui-monospace` fallback. Streaks, dates, counts, handles, code.

| Style | Size / Line | Weight | Use |
|---|---|---|---|
| `display` | 32 / 40 | 600 | Page titles |
| `h1` | 24 / 32 | 600 | Section headers |
| `h2` | 18 / 26 | 600 | Subsections |
| `body` | 16 / 24 | 400 | Default reading text |
| `caption` | 13 / 18 | 400 | Meta, secondary info |
| `monoMd` | 14 / 20 | 500 | Streak counts, dates inline |
| `monoLg` | 24 / 32 | 600 | Hero numbers |

## Spacing

Multiples of 4: `4, 8, 12, 16, 24, 32, 48, 64`. NativeWind: `p-1` (4) through `p-16` (64).

## Radius

`sm: 4` (inputs), `md: 8` (default — buttons), `lg: 12` (cards, modals), `pill: 999`.

## Motion

Subtle, fast, no bounce. `fast: 120ms`, `normal: 200ms`, `slow: 300ms`. Easing: `ease-out`.

## Iconography

- **Line icons only.** Lucide via `lucide-react-native`. Stroke weight 1.5.
- **Avatars** are circular (`radius: 999`), first character of display name as fallback.

## Component primitives

### `Page`
Notion-style scrollable wrapper. Generous side padding (24), no card chrome.

### `PropertyRow`
Notion's inline-editable property: label left (caption-muted), value right (body, tappable).
```
🗓  Schedule          Daily  ›
🏷  Tags              health, morning  ›
```

### `Heatmap`
53 cols × 7 rows GitHub contribution grid. Cell 11px square on mobile, 2px gap. Tap a cell → date + intensity tooltip.

### `StreakBadge` (or any numeric badge)
Mono count + icon. `monoMd` default, `monoLg` for hero.

## Screen specs

Added by `ux-designer` via `/design`. One entry per screen.
