/**
 * Tailwind / NativeWind preset — Notion + GitHub design system.
 *
 * Mirrors `tokens.ts`. Keep them in sync — when a token changes here,
 * change it there too.
 *
 * Usage in tailwind.config.js:
 *   const dsPreset = require('./lib/design/tailwind.preset');
 *   module.exports = { presets: [dsPreset], content: [...] };
 */

/** @type {import('tailwindcss').Config} */
module.exports = {
  theme: {
    colors: {
      transparent: 'transparent',
      current: 'currentColor',
      // Light defaults — use `dark:` modifier for dark variants
      bg: { DEFAULT: '#ffffff', dark: '#0d1117' },
      surface: { DEFAULT: '#f7f6f3', dark: '#161b22' },
      border: { DEFAULT: '#e9e9e7', dark: '#30363d' },
      divider: { DEFAULT: '#ededec', dark: '#21262d' },
      text: { DEFAULT: '#37352f', dark: '#e6edf3' },
      muted: { DEFAULT: '#787774', dark: '#7d8590' },
      subtle: { DEFAULT: '#9b9a97', dark: '#6e7681' },
      accent: { DEFAULT: '#2383e2', dark: '#388bfd' },
      success: { DEFAULT: '#26a641', dark: '#3fb950' },
      danger: '#f85149',
      warning: '#d29922',
    },
    fontFamily: {
      body: ['Inter', 'system-ui', 'sans-serif'],
      mono: ['JetBrainsMono', 'ui-monospace', 'monospace'],
    },
    fontSize: {
      caption: ['13px', { lineHeight: '18px', fontWeight: '400' }],
      body: ['16px', { lineHeight: '24px', fontWeight: '400' }],
      h2: ['18px', { lineHeight: '26px', fontWeight: '600' }],
      h1: ['24px', { lineHeight: '32px', fontWeight: '600' }],
      display: ['32px', { lineHeight: '40px', fontWeight: '600' }],
      'mono-md': ['14px', { lineHeight: '20px', fontWeight: '500' }],
      'mono-lg': ['24px', { lineHeight: '32px', fontWeight: '600' }],
    },
    spacing: {
      0: 0,
      1: 4,
      2: 8,
      3: 12,
      4: 16,
      6: 24,
      8: 32,
      12: 48,
      16: 64,
    },
    borderRadius: { none: 0, sm: 4, md: 8, lg: 12, pill: 999, full: 9999 },
    extend: {},
  },
  plugins: [],
};
