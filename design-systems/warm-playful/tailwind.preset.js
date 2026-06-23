/**
 * Tailwind / NativeWind preset — Warm Playful design system.
 * Mirrors `tokens.ts`. Keep them in sync.
 */

/** @type {import('tailwindcss').Config} */
module.exports = {
  theme: {
    colors: {
      transparent: 'transparent',
      current: 'currentColor',
      bg: { DEFAULT: '#FFFAF3', dark: '#231811' },
      surface: { DEFAULT: '#FFF1E6', dark: '#2E211A' },
      border: { DEFAULT: '#F0E2D2', dark: '#3F2F25' },
      divider: { DEFAULT: '#F7EBDD', dark: '#352720' },
      text: { DEFAULT: '#3D2E1F', dark: '#FAEBD7' },
      muted: { DEFAULT: '#8C7563', dark: '#B5A18C' },
      subtle: { DEFAULT: '#B5A18C', dark: '#8C7563' },
      accent: { DEFAULT: '#FF8C7A', dark: '#FF9F8C' },
      success: { DEFAULT: '#7DBA8A', dark: '#9ED1A8' },
      danger: { DEFAULT: '#E07A5F', dark: '#F09781' },
      warning: { DEFAULT: '#F2CC8F', dark: '#F2D9A1' },
      // Category palette
      peach: { DEFAULT: '#FBC4AB', dark: '#E89E84' },
      sage: { DEFAULT: '#B5C9A1', dark: '#94AC81' },
      butter: { DEFAULT: '#FFE7A0', dark: '#E0C880' },
      lavender: { DEFAULT: '#D6CDEA', dark: '#B5ABD0' },
      sky: { DEFAULT: '#B8DCE5', dark: '#92BCC7' },
    },
    fontFamily: {
      body: ['Nunito', 'system-ui', 'sans-serif'],
      display: ['Nunito', 'system-ui', 'sans-serif'],
      mono: ['JetBrainsMono', 'ui-monospace', 'monospace'],
    },
    fontSize: {
      caption: ['13px', { lineHeight: '19px', fontWeight: '500' }],
      body: ['16px', { lineHeight: '26px', fontWeight: '500' }],
      h2: ['18px', { lineHeight: '26px', fontWeight: '700' }],
      h1: ['24px', { lineHeight: '32px', fontWeight: '700' }],
      display: ['32px', { lineHeight: '42px', fontWeight: '800' }],
      'mono-md': ['14px', { lineHeight: '20px', fontWeight: '500' }],
    },
    spacing: { 0: 0, 1: 4, 2: 8, 3: 12, 4: 16, 6: 24, 8: 32, 12: 48, 16: 64 },
    borderRadius: { none: 0, sm: 12, md: 16, lg: 24, xl: 32, pill: 999, full: 9999 },
    extend: {
      transitionTimingFunction: {
        bouncy: 'cubic-bezier(0.34, 1.56, 0.64, 1)',
      },
      transitionDuration: { fast: '200ms', normal: '350ms', slow: '500ms' },
    },
  },
  plugins: [],
};
