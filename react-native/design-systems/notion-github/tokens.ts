/**
 * Design tokens — Notion + GitHub
 *
 * Calm document feel + data-dense surfaces. Built for productivity apps where
 * the user spends a lot of time reading and editing. Cross-platform safe
 * (iOS / Android / web).
 *
 * Single source of truth. Components import from here — no magic values.
 */

export const colors = {
  light: {
    bg: '#ffffff',
    surface: '#f7f6f3',     // Notion warm gray
    border: '#e9e9e7',
    divider: '#ededec',
    text: '#37352f',        // Notion ink
    muted: '#787774',
    subtle: '#9b9a97',
    accent: '#2383e2',      // Notion blue
    success: '#26a641',     // GitHub mid-green
    danger: '#f85149',
    warning: '#d29922',
    // GitHub contribution scale, light theme
    heatmap: ['#ebedf0', '#9be9a8', '#40c463', '#30a14e', '#216e39'] as const,
  },
  dark: {
    bg: '#0d1117',          // GitHub dark
    surface: '#161b22',
    border: '#30363d',
    divider: '#21262d',
    text: '#e6edf3',        // GitHub fg
    muted: '#7d8590',
    subtle: '#6e7681',
    accent: '#388bfd',      // accessible blue on dark
    success: '#3fb950',
    danger: '#f85149',
    warning: '#d29922',
    // GitHub contribution scale, dark theme
    heatmap: ['#161b22', '#0e4429', '#006d32', '#26a641', '#39d353'] as const,
  },
} as const;

export const typography = {
  fonts: {
    body: 'Inter',                  // cross-platform — bundle via expo-font
    mono: 'JetBrainsMono',          // for streaks, dates, numbers, code
  },
  // Style: [fontSize, lineHeight, fontWeight]
  styles: {
    display: [32, 40, '600'],
    h1: [24, 32, '600'],
    h2: [18, 26, '600'],
    body: [16, 24, '400'],
    caption: [13, 18, '400'],
    monoMd: [14, 20, '500'],
    monoLg: [24, 32, '600'],
  },
} as const;

export const spacing = [0, 4, 8, 12, 16, 24, 32, 48, 64] as const;

export const radius = {
  sm: 4,
  md: 8,
  lg: 12,
  pill: 999,
} as const;

export const motion = {
  // Notion/GitHub feel: subtle, fast, no bounce. Easing is functional.
  fast: 120,
  normal: 200,
  slow: 300,
  easing: 'ease-out',
} as const;

export const tokens = { colors, typography, spacing, radius, motion } as const;
export type Tokens = typeof tokens;
