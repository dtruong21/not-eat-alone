/**
 * Design tokens — Linear / Vercel minimal
 *
 * High-contrast monochrome. Sharp typography. Generous negative space.
 * Built for modern SaaS tools where the product is the focus and the chrome
 * gets out of the way. Cross-platform safe (iOS / Android / web).
 *
 * Single source of truth. Components import from here — no magic values.
 */

export const colors = {
  light: {
    bg: '#ffffff',
    surface: '#fafafa',
    border: '#eaeaea',
    divider: '#f0f0f0',
    text: '#0a0a0a',          // near-pure black
    muted: '#666666',
    subtle: '#999999',
    accent: '#5e6ad2',        // Linear's purple-blue
    success: '#0a9956',
    danger: '#e5484d',
    warning: '#ee9d2b',
  },
  dark: {
    bg: '#0a0a0a',            // near-pure black
    surface: '#141414',
    border: '#2a2a2a',
    divider: '#1f1f1f',
    text: '#fafafa',
    muted: '#999999',
    subtle: '#666666',
    accent: '#8d95f2',        // accessible on dark
    success: '#3dd68c',
    danger: '#ff6369',
    warning: '#ffb648',
  },
} as const;

export const typography = {
  fonts: {
    body: 'Inter',            // sharp sans-serif; Geist is the upgrade if you bundle it
    mono: 'JetBrainsMono',    // used sparingly, only for code-like elements
  },
  styles: {
    // Tighter line-heights than Notion — Linear's signature density
    display: [40, 44, '700'],
    h1: [28, 32, '600'],
    h2: [20, 26, '600'],
    body: [15, 22, '400'],    // 15 not 16 — Linear's choice
    caption: [13, 18, '400'],
    monoMd: [13, 18, '500'],
  },
  letterSpacing: {
    // Tight tracking on display + h1 — Linear's signature
    display: -0.4,
    h1: -0.3,
    h2: -0.15,
    body: 0,
  },
} as const;

export const spacing = [0, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 96] as const;

export const radius = {
  sm: 4,
  md: 6,                      // sharper than Notion's 8
  lg: 8,
  pill: 999,
} as const;

export const motion = {
  // Snappy, eased, never bouncy. Linear's signature crispness.
  fast: 100,
  normal: 150,
  slow: 250,
  easing: 'cubic-bezier(0.32, 0.72, 0, 1)',  // Linear's easing curve
} as const;

export const tokens = { colors, typography, spacing, radius, motion } as const;
export type Tokens = typeof tokens;
