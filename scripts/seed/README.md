# Stage seed script

Out-of-app Node script (firebase-admin) that populates the **STAGE** Firestore
database with test `users` and `meals` docs, matching the shapes read by
`AppUserDto` / `MealDto` in the Flutter app. Used to exercise the Plan 5
discovery feed against realistic-looking data.

This is **not** part of the Flutter build — it never runs from the app, only
from your machine or CI, against Firebase directly.

## Setup

1. Download a service account key for the Firebase project:
   **Firebase console → Project settings → Service accounts → Generate new
   private key**.
2. Save the downloaded JSON as `scripts/seed/service-account.json` (this path
   is gitignored — never commit it).
3. Install dependencies:

   ```bash
   cd scripts/seed
   npm install
   ```

## Run

```bash
npm run seed
```

Writes ~12 seed users (`users/seed_user_01` … ) and ~18 seed meals
(`meals/seed_meal_01` … ) to Firestore. Writes use `set(..., { merge: true })`
so re-running is safe/idempotent.

**This only ever targets the `stage` named database.** The script asserts the
target database id is `stage` and refuses to run (exits non-zero) if it isn't
— it will never write to `(default)`/production.

## Clean up

```bash
npm run wipe
```

Deletes every `users`/`meals` doc whose id starts with `seed_`.

## Tests

The doc builders (`seed_data.mjs`) are pure functions with no firebase-admin
dependency, so they're unit-tested without any credentials or network access:

```bash
npm test
# or, without installing dependencies:
node --test seed_data.test.mjs
```

## Missing service account

If `service-account.json` is missing, `npm run seed` / `npm run wipe` print a
message telling you to download it from the console (see Setup above) and
exit non-zero — no Firestore call is attempted.
