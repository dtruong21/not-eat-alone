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

- Reminders for your matched meals: a notification the day before and about 2 hours before, with the restaurant and time (tap to open the chat with your match).
- Settings now has a "Contact support" row that opens an email to support, with the address shown on screen.
- A meal's restaurant card now has an "Open in Maps" button that opens the restaurant in your maps app (hidden when a meal has no usable location).
- Restaurant search now finds real restaurants across Paris (previously a fixed list of 20); results update shortly after you stop typing.
- The request inbox now shows which meal each request is for (restaurant and time), marks requests whose meal time has passed (Approve is disabled, Deny still works), and confirms every Approve or Deny with a message, with a Chat shortcut after approving (the approve message dismisses itself after a few seconds).

- A feed that can't load now shows a "Couldn't load this" message with a Try again button (Discover, requests, chats, chat messages, restaurant search).

### Changed

- Lists show placeholder cards while they load (Discover, requests, chats, chat messages, restaurant search) instead of a spinner, and error and empty screens share one design.
- Dates and times are now 24-hour with the day before the month, and read "Today 20:30" or "Tomorrow 12:30" for the next two days (for example "Sat 10 Oct, 20:00"); chat times show as "20:30".
- Secondary text, hints and icons are darker and easier to read (they were as pale as the card outlines); error text and the Deny button are a deeper brick red that is readable on the cream page.
- Buttons now have a clear hierarchy: the main action is coral with a dark brown label, secondary actions are outlined with a dark label, and switches and segmented controls have visible outlines when off. A button that is working keeps its colour and shows a visible spinner.
- Cards (meals, chats, requests, restaurants) now stand out from the page with a soft shadow and a slightly deeper peach; your own chat messages use a warm peach bubble and snackbars are readable in dark mode.
- The Nunito font now ships inside the app instead of being downloaded when it first opens, so text looks the same offline and nothing is fetched from Google.
- Creating a meal now needs a time at least 5 minutes ahead; an earlier pick shows a message instead of being accepted.
- Sign-in: "Continue with Apple" is now Apple's own button (black on the light theme, white on the dark one); the phone number field shows what is wrong with the number right on the field, and when you tap into it the field, its message and "Send code" scroll up above the keyboard; "Send code" keeps its spinner until the code is on its way.
- The phone code screen scrolls (so Verify can be reached at large text sizes and with the keyboard up), shows the number the code went to with a "Change" button and a back arrow, and submits by itself after the sixth digit. A wrong code is explained on the field ("That code didn't work. Check it or resend."), and "Resend code" counts down 30 seconds before it can be used.
- Under-18 date of birth: you are now told why you were signed out ("You must be 18 or older to use Convyve.") on the sign-in screen. The date-of-birth picker opens on the year, and the age gate scrolls at large text sizes.
- Profile setup: the "Add photo" tile is labelled, the remove-photo button on a photo is easy to hit, and a line under Continue says what is still missing ("Still needed: a photo and your name.").

### Fixed

- The phone number is now sent as a clean international number (no spaces, and the leading 0 of a French number such as "+33 06 12 34 56 78" is dropped; a French number with the wrong number of digits is refused before anything is sent).
- A wrong SMS code and a network problem are no longer shown with the same message, and a late "code sent" from a timed-out attempt no longer opens a second code screen.
- Profile form: Continue is no longer hidden by the keyboard while you type your bio, and large text no longer overflows the profile setup, age gate, sign-in or code screens.
- Editing your profile (for example adding a photo) no longer sends you back to Discover or empties the form you were filling in.
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
