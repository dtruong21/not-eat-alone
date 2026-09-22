# Gitflow

Convyve uses a full-gitflow branching model. Two long-lived branches, three
kinds of short-lived branches, releases by tag.

## Branches

| Branch | Role | Branch from | Merge into | Protected |
|---|---|---|---|---|
| `main` | Production. Every merge is a release. | — | — | ✅ |
| `develop` | Integration; maps to the **stage** environment. | `main` | — | ✅ |
| `feature/<slug>` | One feature or task. | `develop` | `develop` | — |
| `release/X.Y.Z` | Version freeze + stabilize before prod. | `develop` | `main` **and** `develop` | — |
| `hotfix/X.Y.Z` | Urgent production fix. | `main` | `main` **and** `develop` | — |

- `main` only ever receives merges from `release/*` and `hotfix/*`. Feature work never targets `main`.
- Tags `vX.Y.Z` exist only on `main`; each tag == one GitHub Release.
- `develop` is what the stage app builds against; `main` is what production builds against. (Single Firebase project — the split is by app flavor / Firestore database, not by backend.)

## Environment mapping

| Branch | App flavor | Firestore DB | Audience |
|---|---|---|---|
| `develop` | stage (`com.daki.noteatalone.stage`) | `stage` | internal testing |
| `main` | prod (`com.daki.noteatalone`) | `(default)` | store users |

## Flows

### Feature

```bash
git checkout develop && git pull
git checkout -b feature/my-thing
# ...work, commit...
git push -u origin feature/my-thing
# open PR: feature/my-thing -> develop  (CI must pass)
# merge, then delete the branch
```

### Release (cut a production version)

```bash
git checkout develop && git pull
git checkout -b release/1.1.0
# bump version in pubspec.yaml -> 1.1.0+<build>   (see /bump)
# fix ONLY release blockers here
git push -u origin release/1.1.0
# open PR: release/1.1.0 -> main  (CI must pass), merge
git checkout main && git pull
git tag v1.1.0 && git push origin v1.1.0   # -> GitHub Release + prod deploy
# back-merge so the version bump + fixes return to integration:
git checkout develop && git merge --no-ff main && git push
```

### Hotfix (urgent prod fix)

```bash
git checkout main && git pull
git checkout -b hotfix/1.1.1
# fix, bump patch version in pubspec.yaml
git push -u origin hotfix/1.1.1
# open PR: hotfix/1.1.1 -> main, merge
git checkout main && git pull
git tag v1.1.1 && git push origin v1.1.1
git checkout develop && git merge --no-ff main && git push
```

## Branch protection

`main` and `develop` require: a PR before merge, the CI checks green
(`Analyze & test`, `Build Android (stage, unsigned)`, `Build iOS (stage, no
codesign)`), and the branch up to date. No force-push, no deletion. Solo
project: 0 required approvals and admin bypass left on — tighten both when a
collaborator joins.

## What CI/CD does per branch

See `docs/CICD.md`. Short version: every PR runs the gate; a merge to
`develop` or `main` deploys the Firebase backend; a `v*` tag publishes a
release. App-store builds are a later additive step.
