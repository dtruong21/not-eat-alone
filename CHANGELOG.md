# Changelog

All notable changes to Convyve that affect users. Format follows [Keep a Changelog](https://keepachangelog.com/). This project adheres to [Semantic Versioning](https://semver.org/) — see [`docs/VERSIONING.md`](docs/VERSIONING.md) for the bump policy.

**Rule:** Only user-visible changes go here. Internal refactors, dev tooling, test additions, codegen updates, and CI tweaks do NOT belong in this file. If a user couldn't notice the change, it doesn't get a line.

**Conventions for `[Unreleased]` entries** (drives `/bump` semantics — see [`docs/VERSIONING.md`](docs/VERSIONING.md)):

| Section | Used for | SemVer bump on cut |
|---|---|---|
| `### Added` | New user-facing capability | MINOR |
| `### Changed` | Visible behavior change in existing feature | PATCH (or MAJOR if "(BREAKING)") |
| `### Fixed` | Bug fix | PATCH |
| `### Deprecated` | Feature marked for removal in next major | MINOR |
| `### Removed` | Feature removed | MAJOR |
| `### Security` | User-visible security fix | PATCH |

`/bump` reads this file and decides the bump for you. Override with `/bump major` etc. when the heuristic is wrong.

---

## [Unreleased]

### Added

### Changed

- Creating a meal now needs a time at least 5 minutes ahead; an earlier pick shows a message instead of being accepted.

### Fixed

- A match can no longer be created without a real, pending, approved request (closes fabricated matches that allowed unsolicited chat and ratings).
- A meal's host, time and restaurant can no longer be changed after it is posted, and a meal can only become matched through a genuine approve of a guest's request.
- A request can only be decided once; an approved or denied request can no longer be flipped (which re-notified the guest each time).
- A rating can only be left once the meal has happened.
- Meals can no longer be deleted from the app, so a host can't delete and re-post a meal under the same requests to change its details.

---

## [0.0.1] — 2026-09-18

- Initial scaffolding from Flutter project template
