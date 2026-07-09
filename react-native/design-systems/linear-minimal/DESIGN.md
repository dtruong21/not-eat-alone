# Design System — Linear / Vercel Minimal

High-contrast monochrome, sharp typography, generous negative space. The chrome gets out of the way so the product can speak.

**Best for:** modern SaaS tools, developer-facing apps, anything where seriousness and speed are the brand.

**Platforms:** iOS, Android, web.

## Aesthetic principles

1. **Monochrome with one accent.** The palette is grayscale. The accent is reserved for primary actions only.
2. **Tight typography.** Negative letter-spacing on titles. Body at 15px, not 16. Density is intentional.
3. **Sharp corners.** Radius stays under 8px. No cards-as-pillows.
4. **Snappy motion.** 100–250ms. Linear's signature easing curve. Never bouncy.
5. **Dark mode is the canonical mode.** Light works, but the brand lives in dark.

## Tokens

Full reference: [`tokens.ts`](tokens.ts).

### Color — surfaces

| Token | Light | Dark |
|---|---|---|
| `bg` | `#ffffff` | `#0a0a0a` |
| `surface` | `#fafafa` | `#141414` |
| `border` | `#eaeaea` | `#2a2a2a` |
| `divider` | `#f0f0f0` | `#1f1f1f` |

### Color — text

| Token | Light | Dark |
|---|---|---|
| `text` | `#0a0a0a` | `#fafafa` |
| `muted` | `#666666` | `#999999` |
| `subtle` | `#999999` | `#666666` |

### Color — accent + semantic

| Token | Light / Dark | Use |
|---|---|---|
| `accent` | `#5e6ad2` / `#8d95f2` | Primary action only — used sparingly |
| `success` | `#0a9956` / `#3dd68c` | Positive state |
| `danger` | `#e5484d` / `#ff6369` | Destructive |
| `warning` | `#ee9d2b` / `#ffb648` | Caution |

**Discipline:** at most one accent-colored element per viewport. If you find two, downgrade one to `text` or `muted`.

## Typography

- **Body**: Inter (or Geist Sans if you bundle it). Tight tracking on titles.
- **Mono**: JetBrains Mono. Used only for code-like elements — IDs, paths, command output. Not for numbers in body copy.

| Style | Size / Line | Weight | Tracking | Use |
|---|---|---|---|---|
| `display` | 40 / 44 | 700 | -0.4 | Page titles |
| `h1` | 28 / 32 | 600 | -0.3 | Section headers |
| `h2` | 20 / 26 | 600 | -0.15 | Subsections |
| `body` | 15 / 22 | 400 | 0 | Default — note 15, not 16 |
| `caption` | 13 / 18 | 400 | 0 | Meta |
| `monoMd` | 13 / 18 | 500 | 0 | Code, paths |

## Spacing

Tighter scale than Notion: `4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 96`. The extra 20 and 40 let you tune density when 16/24/32 feel too coarse.

## Radius

`sm: 4`, `md: 6` (default), `lg: 8`, `pill: 999`. **Stay under 8** — anything rounder breaks the aesthetic.

## Motion

Linear's signature feel:
- `fast: 100ms` — instant feedback (hover, press)
- `normal: 150ms` — most transitions
- `slow: 250ms` — substantial layout changes
- Easing: `cubic-bezier(0.32, 0.72, 0, 1)` — Linear's curve

Never use spring physics. Never bounce. Crispness is the brand.

## Iconography

- **Line icons only.** Lucide stroke 1.5. Same as Notion-GitHub.
- **No emoji.** Linear doesn't use them. If your product needs personality, get it from type and motion, not from emoji decoration.

## Component primitives

### `CommandPalette`
The flagship pattern. Cmd-K opens a search-driven action picker. Body 15, results in `monoMd`-like compact rows.

### `ListRow`
Dense (44px tall), divider-separated, no card chrome. Title body, secondary muted caption inline-right.

### `Modal`
Backdrop `bg` @ 60% opacity, content surface, radius `md`. Animate in 150ms. Backdrop tap to dismiss.

### `Button`
- **Primary**: `text` bg + `bg` text. Yes — pure black/white inversion is the primary CTA in Linear's world.
- **Accent**: `accent` bg + white text. Reserved for the single most-important action per screen.
- **Ghost**: transparent bg + `text`. Default for secondary actions.

### `KeyboardHint`
Inline `monoMd` chip showing a keyboard shortcut. `border` outline, `surface` bg, 4px radius. Required for any pro-feeling app.

## Screen specs

Added via `/design`.
