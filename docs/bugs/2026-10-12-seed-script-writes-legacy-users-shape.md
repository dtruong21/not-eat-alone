## [P2] `scripts/seed` still seeds the pre-split `users/{id}` shape: seeded hosts have no public profile, so Discover shows nameless hosts (and a re-run re-pollutes `users`)

**Repro:**
1. `cd scripts/seed && npm run seed` against `stage` (TEST-PLAN: "Seed script populates ~12 users + ~18 meals so the feed has content").
2. Open Discover / a seeded meal as a real account.

**Expected:** Each seed user has `users/{id}` (private: uid, dob, ageVerified, gender, createdAt) and `profiles/{id}` (displayName, photoUrls, bio, age); `--wipe` removes both.
**Actual:** `seed_stage.mjs` writes only `users/{id}` with `displayName`, `photoUrls`, `bio` (the pre-split "AppUserDto" shape; untouched since before the split) and never `profiles/{id}`. The app now reads other people's name/photo/age from `profiles/{uid}` only, so every seeded host renders as the neutral placeholder; re-running the seed after the rules are deployed also re-adds public keys to `users/{id}` (the Admin SDK bypasses rules). `--wipe` deletes `users` but leaves any `profiles`. The stage database is what QA and the store-review demo rely on.

**Device/OS:** code reading (`scripts/seed/seed_stage.mjs` lines 87-97, 138); `seed_data.test.mjs` still asserts the old shape.
**Build:** develop @ 979e5f2
**Frequency:** always.

**Hypothesis / fix:** split `buildSeedUsers()` output into a private and a public doc (public age derived from dob), write both in the batch, wipe both collections, update `seed_data.test.mjs` and the TEST-PLAN seed line.
