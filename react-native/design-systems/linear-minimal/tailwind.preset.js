/**
 * Tailwind / NativeWind preset — Linear / Vercel minimal design system.
 * Mirrors `tokens.ts`. Keep them in sync.
 */

/** @type {import('tailwindcss').Config} */
module.exports = {
  theme: {
    colors: {
      transparent: 'transparent',
      current: 'currentColor',
      bg: { DEFAULT: '#ffffff', dark: '#0a0a0a' },
      surface: { DEFAULT: '#fafafa', dark: '#141414' },
      border: { DEFAULT: '#eaeaea', dark: '#2a2a2a' },
      divider: { DEFAULT: '#f0f0f0', dark: '#1f1f1f' },
      text: { DEFAULT: '#0a0a0a', dark: '#fafafa' },
      muted: { DEFAULT: '#666666', dark: '#999999' },
      subtle: { DEFAULT: '#999999', dark: '#666666' },
      accent: { DEFAULT: '#5e6ad2', dark: '#8d95f2' },
      success: { DEFAULT: '#0a9956', dark: '#3dd68c' },
      danger: { DEFAULT: '#e5484d', dark: '#ff6369' },
      warning: { DEFAULT: '#ee9d2b', dark: '#ffb648' },
    },
    fontFamily: {
      body: ['Inter', 'system-ui', 'sans-serif'],
      mono: ['JetBrainsMono', 'ui-monospace', 'monospace'],
    },
    fontSize: {
      caption: ['13px', { lineHeight: '18px', fontWeight: '400' }],
      body: ['15px', { lineHeight: '22px', fontWeight: '400' }],
      h2: ['20px', { lineHeight: '26px', fontWeight: '600', letterSpacing: '-0.15px' }],
      h1: ['28px', { lineHeight: '32px', fontWeight: '600', letterSpacing: '-0.3px' }],
      display: ['40px', { lineHeight: '44px', fontWeight: '700', letterSpacing: '-0.4px' }],
      'mono-md': ['13px', { lineHeight: '18px', fontWeight: '500' }],
    },
    spacing: {
      0: 0,
      1: 4,
      2: 8,
      3: 12,
      4: 16,
      5: 20,
      6: 24,
      8: 32,
      10: 40,
      12: 48,
      16: 64,
      24: 96,
    },
    borderRadius: { none: 0, sm: 4, md: 6, lg: 8, pill: 999, full: 9999 },
    extend: {
      transitionDuration: { fast: '100ms', normal: '150ms', slow: '250ms' },
      transitionTimingFunction: {
        linear: 'cubic-bezier(0.32, 0.72, 0, 1)',
      },
    },
  },
  plugins: [],
};
