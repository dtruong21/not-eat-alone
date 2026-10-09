# UX capture harness

Photographs the real app on the iOS Simulator, in every screen state the
seeded world can reach, across a device x theme x text-size matrix. The
screenshots are the evidence for the UX audit (`docs/ux/AUDIT.md`) and later
the store listing. Dev tooling only: not part of CI, not under
`integration_test/` (so `make e2e` never runs it), nothing here ships in the app.

## Run it

One cell (about 5 min: Xcode build, emulators, ~60 captures):

    make ux-capture DEVICE='Convyve E2E' OUT=iphone17-light-default

The whole matrix (8 cells, about 1 hour; creates the "Convyve UX Small"
simulator on first use):

    tool/ux_matrix.sh                  # everything
    tool/ux_matrix.sh --only se3-dark  # cells whose name contains this
    tool/ux_matrix.sh --verify         # only check ux_audit/out

Needs the same tools as `make e2e` (fvm, Firebase CLI, Java 21, npm) and
Python 3 (placeholder avatars). Output: `ux_audit/out/<device>-<theme>-<size>/NN_name.png`
(gitignored), plus `ux_audit/out/logs/<cell>.log` and `<cell>.findings.txt`.

| Cell part | Values |
|---|---|
| device | `iphone17` = simulator "Convyve E2E" (iPhone 17 Pro, 402x874 pt); `se3` = "Convyve UX Small" (iPhone SE 3rd gen, 375x667 pt, same iOS runtime) |
| theme | `light`, `dark` (`xcrun simctl ui <device> appearance`) |
| size | `default` = iOS "large"; `xxl` = `accessibility-extra-large` (`xcrun simctl ui <device> content_size`) |

`tool/ux_matrix.sh` only touches those two simulators (never the generic
"iPhone 17 Pro"), and puts their appearance and text size back to what they
were at the start, also on Ctrl-C. It ends with a verification: every cell
has the same number of PNGs and none is suspiciously small (< 15 kB, i.e.
blank).

## How it works

1. `ux_audit/capture_test.dart` boots the real app (`bootstrap`) against the
   Firebase emulators and walks the screens. It runs with `flutter drive`
   (`ux_audit/driver.dart`), because `flutter test` only runs on a device for
   files under `integration_test/`.
2. `ux_audit/support/world.dart` seeds a realistic world through the
   emulator's admin REST API (rules bypassed), in two stages so the empty
   states can be photographed first: `seedUsers()` (8 users with photos,
   a block) and `seedMeals()` (13+ meals, requests in every state, two
   matches with chats, a past meal with a rating).
3. At each state the test calls `shot('NN_name')` (`support/handoff.dart`):
   it writes `/tmp/convyve-ux/NN_name.ready`; `tool/ux_capture.sh` runs
   `xcrun simctl io <device> screenshot` and writes `.ack`. The test binding
   renders frames on its own while the test waits for the ack, so the photograph
   shows whatever the app is doing at that moment: a state that is transient
   (a spinner) has to be held, see "In-flight states". All waits are bounded
   (30 s per shot, 15 s for the screenshot call itself). `hostCommand(...)` (same folder)
   asks the host to freeze/thaw an emulator, see "In-flight states".
4. A step that fails is logged (`UXSTEP FAIL`) and skipped, so one broken state
   costs one PNG; the run still fails at the end. Layout overflows are not
   failures but audit findings: each one prints `UXOVERFLOW <shot>: ...` and is
   collected in `<cell>.findings.txt`.
5. Avatars are generated placeholders (`tool/ux_images.py`) served on
   `127.0.0.1:8765`.

## Assumptions and caveats

- **Location** is revoked for the app by the Makefile's `ios-privacy` step (and
  re-applied every 2 s by `ux_capture.sh`), so Discover uses its Paris fallback
  and shows the Paris-only notice. The app has **no location-denied banner**:
  denial is silent, so there is no such screen to photograph.
- **Notifications:** iOS' permission alert cannot be pre-decided with
  `simctl privacy`; the test answers firebase_messaging's
  `requestPermission` with "denied" (the real plugin handles all other calls).
- **Time-relative data:** seed times are relative to the moment of the run
  ("tonight 20:30", "+5 days", chat timestamps), so date lines and the status-bar
  clock differ between runs and, slightly, between cells. After ~19:30 "tonight"
  becomes "tomorrow 12:30". Compare structure, not text.
- **Fonts:** Nunito is a bundled asset (`assets/fonts/`) applied to every text
  style, so there is no font download to wait for.
- The app boots once per process, so every cell is its own `flutter drive` run.
- A native alert that gets stuck on a simulator (rare) needs
  `xcrun simctl shutdown/boot` of that device.

## Shots

Numbering is by screen, not capture order; names sort in flow order. 65 per cell
(one file per name below, `<name>.png`).

| Range | Screen | Shots |
|---|---|---|
| 01-06 | Sign-in, phone code | `01_signin`, `02_signin_phone_error`, `03_signin_phone_waiting`, `04_phone_verify`, `05_phone_verify_in_flight`, `06_phone_verify_error` |
| 10-16 | Age gate, profile setup | `10_age_gate`, `11_age_gate_picker`, `12_age_gate_under18_selected`, `14_profile_setup_empty`, `15_profile_setup_filled`, `16_profile_setup_ready` |
| 20-26 | Discover | `20_discover_loading`, `21_discover_empty`, `22_discover_data` (Paris notice shown), `23_discover_scrolled`, `24_discover_notice_dismissed`, `25_discover_refreshing` (pull to refresh), `26_discover_meal_created` (confirmation snackbar) |
| 30-37 | Create a meal | `30_restaurant_search`, `31_restaurant_search_no_matches`, `32_restaurant_search_filtered`, `33_create_meal_empty`, `34_create_meal_date_picker`, `35_create_meal_time_picker`, `36_create_meal_filled`, `37_create_meal_in_flight` |
| 40-49 | Meal detail | `40_meal_detail_open` (idle "Request to join"), `42_meal_detail_requested`, `43_meal_detail_matched`, `44_meal_detail_not_selected`, `45_meal_detail_women_only` (as a woman), `46_meal_detail_women_only_disabled` (as a man), `47_meal_detail_menu` (report/block), `48_meal_detail_own`, `49_meal_detail_request_rejected` |
| 51-55 | Requests inbox | `51_requests_empty`, `52_requests_data` (two pending, one past-meal chip), `53_requests_scrolled`, `54_requests_approve_in_flight`, `55_requests_deny_in_flight` |
| 60-75 | Chats | `60_chats_loading`, `61_chats_empty`, `62_chats_data`, `63_chat_messages` (safety tips, "Seen"), `64_chat_messages_older`, `65_chat_empty`, `66_chat_send_pending`, `67_chat_menu`, `68_chat_report_sheet`, `69_chat_report_filled`, `70_chat_report_in_flight`, `71_chat_block_dialog`, `72_chat_post_meal_card`, `73_rating_sheet`, `74_rating_sheet_filled`, `75_rating_sheet_in_flight` |
| 80-85 | Profile, settings | `80_profile_edit`, `81_profile_edit_scrolled`, `83_settings` (the whole list: it fits one screen), `85_settings_delete_dialog` |
| 90-93 | Error states (last stage) | `90_chat_error`, `91_requests_error`, `92_chats_error`, `93_discover_error` |

Keyboards: a text field that is focused by the test raises the iOS keyboard, as
it would for a user, so some form shots show it.

## Error states (90-93)

Run as the last stage before onboarding, because each poisoned feed stays in its
error state. One deliberately malformed doc per feed (`seedMalformed` in
`support/world.dart`: a message without `text`, a pending request, a match and
an open Paris meal each without their required fields) makes the repository
stream throw `RepositoryParseException`, which the screens render as "Something
went wrong - please try again." (from plan 16b: the shared `ErrorState`, "Couldn't
load this" with a Try again button). No change to the app. All four are written
together: Riverpod 3 retries a failed provider (10 times, back-off up to 6.4 s,
about 40 s) and shows the loading state in between, so the error only stays on
screen once the retries are exhausted; the test waits for that once (up to 90 s)
and then visits the four screens. Before plan 16b the error text had no retry button or other
affordance, which is what the audit saw (`16a-*` captures). There is no offline UI in the app, so
there is no offline state to photograph.

## In-flight states

A local emulator answers in a few milliseconds, and the live test binding
renders frames on its own, so a spinner that waits on the server is gone before
the host can photograph it. The harness holds those states instead of racing
them: `_tapInFlight` (in `capture_test.dart`) asks the host (`hostCommand`) to
**freeze the emulator** with SIGSTOP (Firestore's java process, or the
firebase-tools process that hosts the Auth emulator, which also hosts the
Functions emulator, so Cloud Function triggers stall too), taps, photographs,
then thaws (SIGCONT). The host only signals a process when exactly ONE running
process matches this project (`project_id` / `project not-eat-alone`); with
zero or several matches (another run of this project) it refuses and the shot
is logged as `UXMISSING`. Nothing of another project is ever matched. While it is frozen the
server never answers, so the app stays exactly in its "waiting" state. A watchdog
process started with every freeze also thaws after 25 s, whatever the host
loop is doing, and the host thaws on exit. Nothing in the app is changed.

| In-flight shots | Frozen |
|---|---|
| `05_phone_verify_in_flight` (Auth), `03_signin_phone_waiting` (Auth) | Auth emulator |
| `37_create_meal_in_flight`, `54_requests_approve_in_flight`, `55_requests_deny_in_flight`, `66_chat_send_pending`, `70_chat_report_in_flight`, `75_rating_sheet_in_flight`, `60_chats_loading` | Firestore emulator |
| `25_discover_refreshing` | nothing (the refresh indicator is held by pumping a fixed time) |
| `20_discover_loading` (a skeleton list since plan 16b, was a spinner) | Firestore emulator, frozen after the viewer's own doc has arrived and before the feed's meal query is answered |

What the in-flight shots show is worth reading rather than assuming:
`03_signin_phone_waiting` has **no** indicator (the button spinner is gone as soon
as the request is dispatched, before the code arrives); `54`/`55` have no
spinner either, only disabled buttons (and `55`'s tile may already be gone: the
write is applied locally first).

## Reached through a seed, an admin write or a pushed route

Everything else is tapped and typed in the real UI. These are not:

| Shot | How it is reached | Why |
|---|---|---|
| 21, 51, 61 (empty feeds) | Seed stage 1 has users only; stage 2 (meals) is written afterwards | No UI path to "nothing exists" once the world is seeded |
| 43 `matched` | The viewer taps "Request to join" for real; an admin write then sets the request to `approved` (what the host's Approve does) while the screen is open | The approving host is another user on another device |
| 44 `not_selected` | A seeded `denied` request | Same |
| 46 `women_only_disabled` | Sign in as Dario (a man) and push `/meals/detail` with the seeded women-only meal | Discover hides women-only meals from men. Flipping the viewer's gender while the screen is open does not work either, see "App behaviours found" |
| 48 `own` | Push `/meals/detail` with the viewer's own seeded meal | Discover excludes own meals and there is no "my meals" list: this state has no UI path |
| 49 `request_rejected` | The meal is set to `matched` by an admin write after the detail screen loaded it, then the viewer taps "Request to join"; the rules reject it | A stale screen; the server rejects the write |
| 16 `profile_setup_ready` | An admin write adds a photo URL to the new user | The photo picker is a native sheet the harness cannot drive |
| 02, 04, 06 (sign-in / code) | Real UI against the Auth emulator (a malformed number; a valid one, accepted without an SMS; a wrong code) | none |

## Not captured

- **Under-18 "blocked" screen** (`AgeGateScreen` with the block icon): the
  controller signs the user out first (`age_gate_controller.dart`), and its
  `blocked` state is only set after `signOut` returns. Signing out flips the
  auth state, the router is rebuilt and the age gate is unmounted before that
  state exists, so the blocked layout never reaches a frame. No seeded condition
  changes that order (it is all client-side, with no server round trip to hold,
  unlike the in-flight states), and showing it needs an app change. The nearest
  states are `12_age_gate_under18_selected` and the sign-in screen it ends on.
- **Age-gate Continue, profile-setup Continue, profile Save, and "Request to
  join" in flight**: the write is applied locally at once, which moves the router
  on (age gate -> profile setup, setup -> Discover, any user-doc change -> reset
  to Discover) or swaps the button to the optimistic "Requested", before a
  spinner can be held even with the server frozen. For the audit this means:
  no progress feedback is ever visible there. `40_open` is the idle button,
  `42_requested` what follows.
- **Requests-inbox loading**: the shell's badge already watches the inbox, so it
  is loaded before the tab is first opened. **Restaurant-search loading**: the
  search is an in-memory fake that answers in the same frame.
- **Sign-in with Google / Apple in flight**: native sheets.
- **Location-denied banner**: the spec lists it, the app has none. Denial is
  silent (Paris fallback + the Paris-only notice, shot 22).
- **Offline state**: the app has none. **Error states** of the other
  screens (restaurant search, profile, sign-in with Google/Apple) need a failing
  repository that no seeded document can cause; sign-in (02), code (06) and the
  four feeds (90-93) are covered.
- **Native surfaces**: the photo picker, the iOS notification and location
  alerts, and `url_launcher` pages (Privacy, Terms) are not Flutter widgets.
- **Account deletion, sign-out, block**: the dialogs are photographed and
  cancelled. (A report and a rating are really submitted, shots 70 and 75, and a
  message really sent, shot 66; a request is really approved and another denied,
  54 and 55; these write to the throwaway emulator world.)

## App behaviours found while building the harness (for the audit)

- FIXED in plan 16b (kept as history): any change of the signed-in user's own
  `users/{uid}` doc used to rebuild the router, which reset the navigation stack
  to Discover and dropped in-progress form state (profile photo added during
  profile setup emptied the form; gender flipped on a meal-detail screen). The
  router is now built once; step `16_profile_setup_ready` prints
  `UXCHECK router: ... kept its input after a user-doc write: true|false`.
- A rejected join request leaves no error: the button that listens for the
  failure is replaced by the optimistic "Requested" state and back (shot 49).
- `verifyPhoneNumber` returns as soon as the request is dispatched, so the
  "Send code" spinner vanishes before the code screen appears (shot 03).
- Nunito is applied to two text styles only (see Caveats).

## Last full matrix run (2026-10-06)

`tool/ux_matrix.sh`: 8 cells, 65 distinct screenshots (including the four error
states 90-93, which run in every cell), about 8 min per cell, no blank PNG
(smallest > 100 kB). The 4 default-size cells hold all 65; the 4 `xxl` cells
hold 64: `06_phone_verify_error` cannot be produced at the large text size,
because the code screen's "Verify" button ends up behind the keyboard or off the
screen (the screen does not scroll), so the wrong-code request is never sent.
Logged per cell in `ux_audit/out/logs/<cell>.findings.txt`:

| Cell | `UXOVERFLOW` lines | `UXMISSING` (in-flight spinner not reachable) |
|---|---|---|
| iphone17-{light,dark}-default | 0 | none |
| iphone17-{light,dark}-xxl | 19 | 05, 66, 70, 75 |
| se3-{light,dark}-default | 3 | 70, 75 |
| se3-{light,dark}-xxl | 31 | 05, 66, 70, 75 |

- `UXOVERFLOW <shot>: A RenderFlex overflowed by N pixels on the ...` is Flutter's
  overflow report (the yellow/black stripes are also visible in the PNG). The shot
  name is the one being prepared when it was reported, so it can be one step
  late; the PNG is the evidence. Seen: sign-in at large text; Discover's Paris
  notice and the meal detail at large text (195 px to the right); the report
  and rating sheets with their field focused (the Submit button ends up under
  the keyboard) already at default text on the small phone; the post-meal card at
  large text.
- `UXMISSING <shot>`: the tap that should have started the action landed on
  nothing (the button is off screen or under the keyboard), so no spinner
  appears. 05 = Verify on the code screen, 66 = chat send button with the
  keyboard open, 70 = report Submit, 75 = rating Submit. Their PNGs exist and
  show the screen as the user would see it.
- One freeze was refused by the single-match safety check ("NOT freezing
  firestore: 2 processes match", in `se3-dark-xxl` only, for
  `54_requests_approve_in_flight`): that PNG was taken without the freeze and
  may not show the in-flight state.
