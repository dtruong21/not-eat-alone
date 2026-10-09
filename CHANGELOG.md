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

- Settings now has a "Contact support" row that opens an email to support, with the address shown on screen.
- A meal's restaurant card now has an "Open in Maps" button that opens the restaurant in your maps app (hidden when a meal has no usable location).
- Restaurant search now finds real restaurants across Paris (previously a fixed list of 20); results update shortly after you stop typing.
- The request inbox now shows which meal each request is for (restaurant and time), marks requests whose meal time has passed (Approve is disabled, Deny still works), and confirms every Approve or Deny with a message, with a Chat shortcut after approving (the approve message dismisses itself after a few seconds).

### Changed

- Secondary text, hints and icons are darker and easier to read (they were as pale as the card outlines); error text and the Deny button are a deeper brick red that is readable on the cream page.
- Buttons now have a clear hierarchy: the main action is coral with a dark brown label, secondary actions are outlined with a dark label, and switches and segmented controls have visible outlines when off. A button that is working keeps its colour and shows a visible spinner.
- Cards (meals, chats, requests, restaurants) now stand out from the page with a soft shadow and a slightly deeper peach; your own chat messages use a warm peach bubble and snackbars are readable in dark mode.
- The Nunito font now ships inside the app instead of being downloaded when it first opens, so text looks the same offline and nothing is fetched from Google.
- Creating a meal now needs a time at least 5 minutes ahead; an earlier pick shows a message instead of being accepted.

### Fixed

- The "add photo" tile on the profile now has a visible outline.
- Chat message times now show in your local time instead of UTC.
- Meal times now show in your local time instead of UTC (a 7:30 PM meal in Paris no longer reads 5:30 PM).
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
