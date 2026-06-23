/**
 * Design tokens — Warm Playful
 *
 * Soft pastel palette, rounded corners, gentle spring motion. Built for
 * consumer / wellness / habit / journaling apps where warmth and approachability
 * matter more than density. Cross-platform safe (iOS / Android / web).
 *
 * Single source of truth. Components import from here — no magic values.
 */

export const colors = {
  light: {
    bg: '#FFFAF3',            // cream — never pure white
    surface: '#FFF1E6',       // warm peach surface
    border: '#F0E2D2',
    divider: '#F7EBDD',
    text: '#3D2E1F',          // warm dark brown, not black
    muted: '#8C7563',
    subtle: '#B5A18C',
    accent: '#FF8C7A',        // warm coral
    success: '#7DBA8A',       // sage green
    danger: '#E07A5F',        // terracotta
    warning: '#F2CC8F',       // butter yellow
    // Bonus accent palette — use sparingly for category/tag/illustration accents
    palette: {
      peach: '#FBC4AB',
      sage: '#B5C9A1',
      butter: '#FFE7A0',
      lavender: '#D6CDEA',
      sky: '#B8DCE5',
    },
  },
  dark: {
    bg: '#231811',            // warm-toned dark, not gray
    surface: '#2E211A',
    border: '#3F2F25',
    divider: '#352720',
    text: '#FAEBD7',
    muted: '#B5A18C',
    subtle: '#8C7563',
    accent: '#FF9F8C',
    success: '#9ED1A8',
    danger: '#F09781',
    warning: '#F2D9A1',
    palette: {
      peach: '#E89E84',
      sage: '#94AC81',
      butter: '#E0C880',
      lavender: '#B5ABD0',
      sky: '#92BCC7',
    },
  },
} as const;

export const typography = {
  fonts: {
    body: 'Nunito',           // rounded sans — friendly, readable
    display: 'Nunito',        // same family, heavier weights
    mono: 'JetBrainsMono',    // rarely needed in this system
  },
  styles: {
    display: [32, 42, '800'], // heavier weights — Nunito carries weight well
    h1: [24, 32, '700'],
    h2: [18, 26, '700'],
    body: [16, 26, '500'],    // slightly looser line, medium weight
    caption: [13, 19, '500'],
    monoMd: [14, 20, '500'],
  },
} as const;

// More generous than Linear, similar feel to Notion — but rounder neighbors.
export const spacing = [0, 4, 8, 12, 16, 24, 32, 48, 64] as const;

export const radius = {
  // Significantly more rounded than the other systems — this is the signature.
  sm: 12,
  md: 16,
  lg: 24,
  xl: 32,
  pill: 999,
} as const;

export const motion = {
  // Spring physics with a touch of bounce. Gentle, never aggressive.
  fast: 200,
  normal: 350,
  slow: 500,
  // For Reanimated: prefer withSpring with these params
  spring: {
    damping: 14,
    stiffness: 180,
    mass: 1,
  },
  easing: 'cubic-bezier(0.34, 1.56, 0.64, 1)',  // gentle back-out
} as const;

export const tokens = { colors, typography, spacing, radius, motion } as const;
export type Tokens = typeof tokens;
