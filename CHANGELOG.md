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

- Convyve now speaks French as well as English: every screen, button, message and accessibility label. It follows your phone's language the first time you open the app, and Settings has a new Language row (System default / English / Français) that switches at once and is remembered.

- A chat now says which meal it is about (restaurant and time, tap to open the meal), the safety tips are a one-line banner you can dismiss that opens the full tips, and messages are grouped under Today / Yesterday / date labels with a time only on the last message of a burst.
- "Can't make it": in a chat for an upcoming meal, the host can cancel the meal or the guest can withdraw. The other person is told, a cancelled meal is removed, and a withdrawn meal opens up again for others.
- Reminders for your matched meals: a notification the day before and about 2 hours before, with the restaurant and time (tap to open the chat with your match).
- Settings now has a "Contact support" row that opens an email to support, with the address shown on screen.
- A meal's restaurant card now has an "Open in Maps" button that opens the restaurant in your maps app (hidden when a meal has no usable location).
- Restaurant search now finds real restaurants across Paris (previously a fixed list of 20); results update shortly after you stop typing.
- The request inbox now shows which meal each request is for (restaurant and time), marks requests whose meal time has passed (Approve is disabled, Deny still works), and confirms every Approve or Deny with a message, with a Chat shortcut after approving (the approve message dismisses itself after a few seconds).

- A feed that can't load now shows a "Couldn't load this" message with a Try again button (Discover, requests, chats, chat messages, restaurant search).

- A meal page now updates while you are looking at it: if the host cancels the meal it switches to "Meal cancelled" at once, and once a meal has taken place it reads "Meal ended".

### Changed

- Push notifications now arrive in your app's language (English or French), per device: if you use Convyve in French on one phone and in English on another, each gets its own. Update the app and open it once for a device to switch; until then it keeps getting English.
- Dates, times and distances follow the app language (for example "sam. 10 oct., 20:00" and "1,2 km" in French).
- Request inbox: Approve is now a clear coral button and Deny a quiet red one (they stack at large text sizes instead of overflowing), only the request you tapped shows a spinner while the others stay usable, the guest's rating is shown under their name, and the Requests tab has an inbox icon.
- The report, rating and block screens now say who they are about ("Report Sam", "How was your meal with Sam?", "Block Sam?"), the text box has a visible edge, selected reasons and stars are easier to read, and "Block" is red.
- Profile: the tab is titled "Profile" and shows "Your rating" (or "No ratings yet"). Save is only available when you changed your name, bio or gender, and confirms with "Profile saved"; with a blank name it says what is still needed. Photos are saved as soon as you add or remove them.
- A meal the host cancelled now shows "Meal cancelled" on its page instead of a "Request to join" button.
- Settings is now grouped into Account (Edit profile, your phone number, Sign out), Safety, Notifications (iPhone), Legal (with open-source licences) and About, with Delete account last. New Blocked people screen to see and unblock people you blocked, and a Safety tips screen.
- At large text sizes the "Rate <name>" button under the chat's rating prompt moves below the text instead of squeezing it, and screen readers now say "Unblock <name>", "Approving…" / "Denying…" and read Settings group titles as headings.
- The rating prompt in a chat now scrolls with the messages instead of being pinned above them, your message clears from the box as soon as you send it (and comes back if it could not be sent), and the Chats list shows the restaurant and time of each meal, with a "Find a meal" button when you have no chats yet. A chat whose messages fail to load now shows only the retry button.
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
- Meal detail: the request button is now pinned to the bottom of the screen with a short status under it ("Waiting for the host to reply.", "You're matched. Say hi!", "The host chose someone else."); it keeps one size in every state, follows your text size setting, and an approved request shows an "Open chat" button.
- Discover: each meal card shows its date and distance on one line, the last card is no longer hidden behind the "Create a meal" button, a long date wraps instead of hiding the distance, and an empty list explains itself with a single "Create a meal" button. The Paris-only notice now scrolls away with the list and stays dismissed until you restart the app. Sign out moved to Settings, with a confirmation.
- Creating a meal starts the time on the next half hour at least an hour ahead (24-hour clock), the confirmation says where requests will show up, and the form fits large text sizes with the keyboard open.
- Restaurant search says "No restaurants to show yet." instead of "No matches" before you type, and names your query when nothing matches.

### Security

- Your exact date of birth and gender are now private. Other people only see your name, photos, bio, age and rating.

### Fixed
- The Paris-only notice on Discover stays dismissed on this device once you close it, instead of coming back every time you open the app.
- The rating card in a chat now has a short "Rate" button that always fits (the person is now named in the card text), in English and French, at any text size.
- Requesting to join a meal that has just closed now says "This meal is no longer open." instead of a generic failure.
- If something you did while offline (a message, a request, a meal, a rating) is refused by the server once your connection returns, you are now told, instead of the app letting you believe it went through.
- The chat is usable at large text sizes and with the keyboard open (the safety tips no longer fill the screen).
- Chat of a cancelled meal / deleted account now says "This chat is no longer available" with a way back, instead of a generic error; no more false crash reports from it.

- A join request that the server refuses (for example the meal was just matched) now shows "Couldn't send your request. Try again." instead of nothing.
- The phone number is now sent as a clean international number (no spaces, and the leading 0 of a French number such as "+33 06 12 34 56 78" is dropped; a French number with the wrong number of digits is refused before anything is sent).
- A wrong SMS code and a network problem are no longer shown with the same message, and a late "code sent" from a timed-out attempt no longer opens a second code screen.
- Profile form: Continue is no longer hidden by the keyboard while you type your bio, and large text no longer overflows the profile setup, age gate, sign-in or code screens.
- Editing your profile (for example adding a photo) no longer sends you back to Discover or empties the form you were filling in.
- Large photos from modern phone cameras can now be added to your profile (they are resized before upload), and profile pictures use less memory so feeds scroll more smoothly.
- If the person you matched with deletes their account, you are told: a host's meal opens up again for someone else to join, and a guest is told the meal was cancelled. Meals no longer sit as "matched" with nobody coming.
- Discover no longer spins forever when your phone can't get a location fix; it falls back to your last known position, or Paris, after a few seconds.
- With a large system font size, the sign-in buttons, the age screen and the rating and report sheets no longer overflow, and the rating and report sheets scroll when the keyboard is open. In a chat, the meal header and safety-tips banner step aside while you type (and the rating prompt too) so you can still see the conversation.
- Sending a message, creating a meal, requesting to join and rating no longer hang on a spinner when you have no connection; they are saved and delivered when you are back online.
- Discover no longer keeps showing a meal after its start time has passed, and it loads faster by only fetching upcoming meals.
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
