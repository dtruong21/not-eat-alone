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

- The request inbox now shows which meal each request is for (restaurant and time), marks requests whose meal time has passed (Approve is disabled, Deny still works), and confirms every Approve or Deny with a message, with a Chat shortcut after approving.

### Changed

- Creating a meal now needs a time at least 5 minutes ahead; an earlier pick shows a message instead of being accepted.

### Fixed

- Approving or denying a request in the inbox no longer fails silently: you now see a message when it couldn't be done (for example, the request was already handled).
- A match can no longer be created without a real, pending, approved request (closes fabricated matches that allowed unsolicited chat and ratings).
- A meal's host, time and restaurant can no longer be changed (or the meal deleted and re-posted under the same requests) after it is posted, and a meal can only become matched through a genuine approve of a guest's request.
- A request can only be decided once; an approved or denied request can no longer be flipped (which re-notified the guest each time).
- A rating can only be left once the meal has happened.
- A meal that has already passed can no longer be requested or approved, and an approval only counts once the meal is matched and the match exists (no "approved" with no chat).
- A meal can only be posted with the fields and types the app sends, so a malformed post can no longer break the Discover feed.

---

## [0.0.1] — 2026-09-18

- Initial scaffolding from Flutter project template
