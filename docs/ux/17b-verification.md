# UX plan 17b: verification capture

Plan 17b (Discover, meal detail, create meal, restaurant search) checked on the real app. Simulators "Convyve E2E" (iPhone 17 Pro, 402x874 pt) and "Convyve UX Small" (iPhone SE 3rd gen, 375x667 pt).
BEFORE = `ux_audit/out/17a-light-default/` (the 17a app, iPhone 17 Pro; no create-meal shots there: for those `ux_audit/out/17b-probe/`, the harness probe run before the 17b UI changes) and, for the small phone at `accessibility-extra-large`, the 2026-10-09 `se3-light-xxl` cell (findings log kept: 18 `UXOVERFLOW` lines). AFTER = `make ux-capture DEVICE='Convyve E2E' OUT=17b-light-default` and `OUT=17b-dark-default` (both exit 0, `UXSUMMARY overflows=0 missingIndicators=0 failedSteps=0`, 68 shots) plus the small-phone xxl cell through `tool/ux_matrix.sh --only se3-light-xxl` (68 shots, no failed step). Local only, not committed. Selected AFTER shots (downscaled): `docs/ux/shots-17b/`.
Seed times and the status-bar clock differ between runs (the seed is relative to "now"): compare structure only. Both simulators were put back to light / `large` afterwards.

## Harness changes (`ux_audit/capture_test.dart`, README updated)

- Finders brought up to date with the new meal-detail bar: `meal_detail_your_meal_button` (was `meal_detail_your_meal_chip`, which made step 48 time out), Discover's empty title "No meals nearby yet" (step 21 waited for the old "No meals near you yet").
- New shot `23b_discover_scrolled_end` (list dragged to the end: DISC-03). 68 shots per cell now (67 before).
- `49_meal_detail_request_rejected` is taken as soon as the snackbar appears (the loop waits for a `SnackBar`, then 600 ms for the slide-in) instead of 6 s after the tap, when the 4 s snackbar was gone; the snackbar is cleared after the shot because it outlives the route and, at large text, covers the create-meal button of the next step (this made steps 26 and 30-37 fail once in the xxl cell).
- `83_settings` waits for the first row (`settings_contact_support`), not the version line: Settings gained a Sign out row, so at xxl the lazy list does not build the version line until it is scrolled to.
- Capture environment: no native notification alert got in the way this time; no simulator reboot was needed.

## Per shot (default size, light unless noted)

| Shot | What changed | Verdict |
|---|---|---|
| `22_discover_data` | The two chips (date, distance) are one muted line, "Today 20:30 · 1.3 km"; the "Women only" badge sits next to the name instead of at the far right; the sign-out icon is gone from the app bar (it is in Settings, with a confirm); the Paris notice is the first item of the list | Fixed. Seen only in the capture: the FAB still overlaps the last visible card while the list is at the top (by design; scroll fixes it, see 23b) |
| `21_discover_empty` | Was an icon and "No meals near you yet" only. Now "No meals nearby yet", "Be the first: host a meal and someone will join." and an inline "Create a meal" button, still under the Paris notice | Fixed. Two "Create a meal" buttons at once (inline + FAB): redundant, P3 |
| `23_discover_scrolled` | One-line meta everywhere; the notice has scrolled out of view with the list (it used to stay pinned above it) | Fixed |
| `23b_discover_scrolled_end` (new) | The list at its very end: the last card ("Chez Gladines") ends clear above the "Create a meal" button, with air between them | DISC-03 verified (also in xxl) |
| `24_discover_notice_dismissed` | Notice gone; the list begins at the first card. Dismissal is per session | Unchanged behaviour, per design |
| `40_meal_detail_open` | "Request to join" is no longer inline under the host: it is pinned in a bar at the bottom (56 pt, `surface` with elevation), always visible. The restaurant card now shows "Open in Maps" (added after the 17a capture, plan 14) | Fixed |
| `42_meal_detail_requested` | Grey disabled "Requested" in the bar with "Waiting for the host to reply." under it (was a button with a hint inside the page). Same bar height as 40 | Fixed. The disabled button is pale (same disabled style as everywhere): P3 |
| `43_meal_detail_matched` | Was a green "Matched! Tap to start chatting" banner. Now a coral "Open chat" button with a chat icon and "You're matched. Say hi!" | Fixed |
| `44_meal_detail_not_selected` | Disabled "Not selected" with "The host chose someone else." in the bar | Fixed |
| `46_meal_detail_women_only_disabled` | Disabled "Women only" with "Only women can join this meal." (was a disabled button with the long "Women only - you don't qualify" text) | Fixed |
| `48_meal_detail_own` | Was a small "Your meal" chip in the page. Now a disabled "This is your meal" button with "See requests in the Requests tab." | Fixed |
| `49_meal_detail_request_rejected` | The rejection shows: the snackbar "Couldn't send your request. Try again." above the bar, the button back to "Request to join" (MEAL-04). The previous run showed nothing (the snackbar was gone after the 6 s wait, and before 17b no listener existed at all). It is the GENERIC copy: `createRequest` wraps every failure, so "This meal is no longer open." cannot show | Fixed (generic copy); specific copy is a follow-up |
| `30`-`32` restaurant search | Unchanged layout; with a long query the no-match line now wraps inside the margins (widget-tested at 320 px). The untouched empty field says "No restaurants to show yet." (widget-tested only: the capture's search always returns the fixed list) | Fixed (copy seen in `31`: "No restaurant called “zzzz”. Try another name.") |
| `33_create_meal_empty` | Same layout; "Pick date & time" and disabled Create meal. The 2.2 px overflow at xxl is gone | Fixed |
| `34`/`35` pickers | The date picker opens on the next slot's day; the time picker is 24 h (clock face 00-23) and opens on 09:00 (07:38 + 1 h rounded up to :00/:30). The 17b-probe opened the clock on the raw minute | Fixed |
| `36_create_meal_filled` | The field says "Today 09:00" (was "Today 15:35": a raw time); the note field is above the keyboard; Create meal is only partly visible above the keyboard in the still photo (the harness does not scroll it into view; reachable, widget-tested at 320 x 568 / 2x) | Fixed |
| `37_create_meal_in_flight` | "Creating…" with the spinner, fields dimmed | Unchanged |
| `26_discover_meal_created` | Snackbar now reads "Meal posted. You'll get requests in the Requests tab." (was "Meal created!") | Fixed |

Dark (`17b-dark-default`): same layouts; the bar, the notice, the empty state and the snackbar (cream on dark) keep readable colours (checked `21`, `43`, `49`). No dark-specific defect found.

## Small phone, `accessibility-extra-large` (se3-light-xxl)

`UXOVERFLOW` lines in `ux_audit/out/logs/se3-light-xxl.findings.txt`: BEFORE 18, AFTER 6.

| Shot(s) | Before | After |
|---|---|---|
| `20_discover_loading` | 13 px bottom | gone |
| `24_discover_notice_dismissed`, `40`, `44`, `45`, `49` | 192 px right (Paris notice, meal detail) | gone |
| `33_create_meal_empty`, `44`, `45`, `46`, `49` | 2.2 px right | gone. It was not reproducible in `CreateMealScreen` alone; it is not logged in this run at any step, so it disappeared with the 17b layout changes (most likely the old inline request button / badge row). Not hunted further because it no longer exists |
| `63`, `65`, `72`, `90` | 55 px bottom (chat, post-meal card, chat error) | unchanged: plan 18 |
| `68` | 11 px bottom (chat report sheet) | unchanged: plan 18 |
| `73` | 118 px bottom (rating sheet) | unchanged: plan 18 |
| `errors_viewer_signin` | 192 px right | gone in this run (not a 17b screen; cause not investigated, the 17a-owned sign-in screen was fixed in 17a) |

Visible at xxl: the pinned bar keeps "Request to join" on screen without scrolling (`40`; before, the button was far below the fold), "Requested / Waiting for the host to reply." (`42`) fits at the same height; the Discover card's meta line is ellipsized (see D3).

## Remaining defects

| # | Defect | Severity | Owner |
|---|---|---|---|
| D1 | `createRequest` wraps every failure in `RepositoryWriteException`: "This meal is no longer open." never shows; the generic snackbar does (MEAL-04 only half-fixed by copy) | P2 | follow-up (repository rethrows `MealNoLongerOpenException`) |
| D2 | Discover card meta line "Sun 18 Oct, 21:…" is cut at xxl, the distance is lost (one line with an ellipsis by design; the Paris notice also takes a whole screen at xxl, but it scrolls away) | P2 | follow-up in Discover (let the meta wrap to two lines at large text) |
| D3 | Chat, report sheet, rating sheet overflow at xxl (55 / 11 / 118 px) | P1 | 18 (chat, ratings) |
| D4 | Requests inbox, chats and settings were not touched by 17b; their remaining issues (in-flight shots `UXMISSING`, etc.) stay with 18 | P2 | 18 |
| D5 | All new strings ("Open chat", "You're matched. Say hi!", "Meal posted…", empty states) are English only | P2 | 19 (French) |
| D6 | Official multicolour Google "G" mark still a Material stand-in | P3 (brand, may block store review) | open from 17a (D1 there): asset task, not 17b |
| D7 | Android phone auto-verification path (`verificationCompleted`) never reports to the screen | P2 | open from 17a (D2 there): 18 or a small auth follow-up |
| D8 | Disabled "Requested" / "Not selected" / "This is your meal" buttons are pale on the cream bar | P3 | follow-up (design token for disabled tonal) |
| D9 | Empty Discover shows two "Create a meal" buttons (inline + FAB) | P3 | follow-up (hide the FAB in the empty state, or keep only the FAB) |
| D10 | Paris notice dismissal is per session (needs `shared_preferences` to persist) | P3 | later decision |

## Not verified by the capture

- VoiceOver on the action bar status live region and on AppButton loading, the action-bar label fit with Nunito at 1.3x on a device (the label asks 58 pt of the fixed 56 pt button), Open in Maps launching the maps app, pull-to-refresh in the empty and error states: manual steps in `docs/TEST-PLAN.md` (17b).
- The loading state of the bar (skeleton) and its "Try again" error state are covered by widget tests only; the "Sending request…" spinner is replaced by the optimistic "Requested" within a frame and cannot be held by the harness.
- "No restaurants to show yet." (the capture's search returns a fixed list).
