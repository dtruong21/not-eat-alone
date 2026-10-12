## [P2] The chained CD deploys rules and functions together on the first `develop` push after the deploy secret is set, which defeats the mandatory backfill-before-rules order in RELEASE.md section 1.5

**Repro (process, no device needed):**
1. `docs/RELEASE.md` 1.5 requires: functions, then `backfill_profiles.js --apply`, then rules, then app build ("Doing [rules] before step 3 makes existing `users` docs un-updatable").
2. `.github/workflows/deploy-firebase.yml` deploys `firestore,storage,functions` in one `firebase deploy` and is chained to every green push to `develop`/`main` as soon as the `FIREBASE_SERVICE_ACCOUNT` secret exists (until then it is a green no-op).
3. The owner sets the secret and merges anything: new rules go live with the new functions before anyone ran the backfill.

**Expected:** The documented order is enforceable.
**Actual:** From that deploy until the backfill is applied, every existing account (stage + prod databases, the rules file is shared) has a `users/{uid}` doc that still holds public fields: owner writes fail (rules emulator case "legacy users doc that still holds public fields", `firebase/rules-test/client_write_shapes.rules.test.cjs`) so saving a profile or gender fails as a whole batch, and everybody shows as the neutral placeholder because `profiles/{uid}` does not exist. Second effect: ratings landing between the functions deploy and the backfill are aggregated into `profiles/{uid}` (created without a `uid` field, which `PublicProfileDto` cannot parse), and the backfill's `set(..., {merge:true})` then overwrites `ratingSum/Count/Avg` with the stale legacy values from `users/{uid}`, losing those ratings. There are no public users yet (store submission planned for November), so impact today is test accounts only; it becomes a real incident if the first deploy happens after launch accounts exist.

**Device/OS:** n/a (emulator + code reading).
**Build:** develop @ 979e5f2
**Frequency:** always on first deploy with existing data.

**Hypothesis / fix:** add a prominent step 0 to RELEASE.md and CICD.md: "do not add `FIREBASE_SERVICE_ACCOUNT` (or run the workflow) until the backfill has been applied to both databases", or make the backfill idempotent-on-demand inside the deploy workflow; make the backfill skip rating fields already present in `profiles/{uid}` (or take the max count) and always write `uid` in `onRatingCreated`'s merge.

**Not verified here:** the real `firebase deploy --non-interactive` against the project (needs credentials and the `PLACES_API_KEY` secret; a missing secret or Storage not enabled fails the whole deploy).
