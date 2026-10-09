# Convyve Cloud Functions

Firebase Cloud Functions for Convyve (push notifications, analytics, and other server-side logic).

## Setup

```bash
npm install
npm run build
npm test
npm run lint
```

## Development

- TypeScript: `src/**/*.ts`
- Compiled output: `lib/` (gitignored)
- Tests: `test/**/*.test.ts` (Task 7+)
- Triggers: Configured in `src/index.ts` (Task 8+)

## Secrets

- `PLACES_API_KEY` (Secret Manager) — used by `searchRestaurants`. Set with `firebase functions:secrets:set PLACES_API_KEY`. See `docs/SECURITY.md` → Google Maps Platform keys.
