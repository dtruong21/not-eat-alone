## [P2] CI path filter can silently report "nothing changed" on a large PR (pipefail + `grep -q`), and it ignores two non-code inputs the tests read; `CI OK` then goes green without running the gate

**Repro (1, deterministic, shell only):**
1. In `.github/workflows/ci.yml` job `changes`, step "Classify changed files" runs with `set -euo pipefail` and `match() { echo "$files" | grep -Eq "$1" && echo true || echo false; }`.
2. With a diff whose file list is larger than the pipe buffer (about 64 KB, roughly 1000+ changed paths - a mass rename, generated assets, a big dependency or asset import) and an early match, `grep -q` exits at the first hit, `echo` gets SIGPIPE, `pipefail` makes the pipeline fail, and `match` prints `false`. Reproduced locally: a 6000-path list containing `lib/a.dart` returned `false` 5 of 5 times for `'^lib/'`.
3. `app`, `functions` and `rules` all become `false`, every heavy job is skipped, and `ci-ok` treats `skipped` as success.

**Repro (2, path gaps):** `tracking_plan_parity_test.dart` reads `docs/TRACKING-PLAN.md` and `push_type_contract_test.dart` reads `firebase/functions/src/lib/payloads.ts`, but the `app` filter matches neither `docs/` nor `firebase/functions/`. A docs-only or functions-only PR that breaks those contracts is green on the PR; the failure only appears on the post-merge push to `develop` (which runs everything and then correctly blocks the chained deploy, but the broken commit is already on `develop`).

**Expected:** The filter never fails open; every file a test reads is in the matching filter.
**Actual:** As above.

**Device/OS:** GitHub Actions ubuntu-latest (bash with `-eo pipefail`); reproduced with local bash. actionlint 1.7.7: clean.
**Build:** develop @ 979e5f2
**Frequency:** the pipefail case needs a very large diff (rare); the path gap is always.

**Hypothesis / fix:** `match() { grep -Eq "$1" <<<"$files" && echo true || echo false; }` (no pipe), and add `^docs/TRACKING-PLAN\.md$` and `^firebase/functions/src/lib/payloads\.ts$` (or all of `firebase/functions/src/`) to the `app` regex. Also consider failing closed: if `git diff` errors or lists >N files, set all three to `true`.

**Notes from the rest of the CI review (no bug):** `CI OK` correctly fails on `failure`/`cancelled` and passes on `skipped`; a failed `changes` job cascades to a failing `CI OK`; push events always run everything, so the chained `deploy-firebase` only ever follows a full green gate; the stale-commit check (`git ls-remote` vs `GITHUB_SHA`) and the per-ref non-cancelling concurrency group behave as intended; `workflow_dispatch` deliberately deploys without the gate. With no `FIREBASE_SERVICE_ACCOUNT` secret the deploy job exits green with a notice, so a green run is not proof of a deployed backend.
