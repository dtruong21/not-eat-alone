# UX plan 17a: verification capture

Plan 17a (sign-in, phone code, age gate, profile setup) checked on the real app. Simulators "Convyve E2E" (iPhone 17 Pro, 402x874 pt) and "Convyve UX Small" (iPhone SE 3rd gen, 375x667 pt).
BEFORE = `ux_audit/out/16b-{light,dark}-default/` (iPhone 17 Pro) and `ux_audit/out/before-se3-light-xxl-16a/` (the small phone at `accessibility-extra-large`, captured 2026-10-06 with the 16a app: the only xxl BEFORE there is). AFTER = `make ux-capture DEVICE='Convyve E2E' OUT=17a-light-default` and `OUT=17a-dark-default`, plus the small-phone xxl cell through `tool/ux_matrix.sh --only se3-light-xxl`. Local only, not committed. Selected AFTER shots (downscaled): `docs/ux/shots-17a/`.
Seed times and the status-bar clock differ between runs; compare structure only. Both simulators were put back to light / `large` afterwards (the matrix script restores "Convyve UX Small" and shuts it down again).

## Harness changes (`ux_audit/capture_test.dart`, README updated)

- `02_signin_phone_error`: the app now refuses an implausible number itself (no round trip) and puts the hint on the field; the step types `+33 12` and waits for "Enter a phone number with country code".
- `03_signin_phone_waiting`: the "Sending code…" spinner now stays until `codeSent`, so the step requires the spinner (`mustShow`).
- `05_phone_verify_in_flight` / `06_phone_verify_error`: the 6th digit submits by itself, so the Auth emulator is frozen BEFORE the code is typed. This is also why `06` now exists at xxl: Verify is no longer needed.
- New `07_phone_verify_resent` (waits out the 30 s cooldown, taps "Resend code", photographs "Code sent again") and `13_signin_underage_notice` (the sign-in screen after an under-18 submit, with the banner). 67 shots per cell now (65 before).
- `_pickYear`: the date picker opens on the year grid, so the header is only tapped when no `YearPicker` is showing.
- `UXCHECK wrong code: field error`: against the Auth emulator the wrong code is mapped to `InvalidSmsCodeException`, i.e. the real "That code didn't work" path was photographed, not the generic sentence.

## Capture environment notes (not 17a defects)

- 9 steps fail in every cell, before and after my changes: `26_discover_meal_created` and `30`-`37` (restaurant search / create meal). Since the Places-backed search (`3d2ad9a`, landed after the 16b capture) the Functions emulator calls `searchRestaurants`, which needs the `PLACES_API_KEY` secret; the harness still expects the old fixed list ("Le Comptoir du Relais"). Needs a stubbed Places response in the harness (own follow-up; the ux-capture exits non-zero because of it, the PNGs and `UXSUMMARY` are written).
- First attempt: a native "Would Like to Send You Notifications" alert was stuck on "Convyve E2E" and covered most shots of that run (as the README warns). Simulator rebooted, both captures re-run; the delivered AFTER set was checked shot by shot.
- The light capture was run twice (the second adds `13`). `17a-dark-default` and the small-phone cell were captured with the final harness.

## Per shot

| Shot | What changed | Verdict |
|---|---|---|
| `01_signin` (light, dark) | Subtitle "Meet one person over a meal in Paris." (was "Sign in to get started."). "Continue with Apple" is Apple's own button: black on light, white on dark, 56 high like Google and Send code (was a 48 high outlined look-alike). Google and Send code are 56 high. | Fixed. New: Apple's label is 24 px, noticeably bigger than the 16 px Google label (see D3) |
| `02_signin_phone_error` | The bare red "Something went wrong" line below the button is gone: the field has a brick-red outline and "Enter a phone number with country code, e.g. +33 6 12 34 56 78" under it; the number is kept. Send code is partly behind the keyboard in the still photo (the field itself is above it) | Fixed (R1 from 16b). Send code still needs a scroll with the keyboard up at default size (D4) |
| `03_signin_phone_waiting` | Was a screen with no indicator at all. Now "Sending code…" with a spinner on the coral button, Google dimmed, Apple dimmed and inert (grey), field disabled | Fixed |
| `04_phone_verify` | Was a vertically centred card with a "0/6" counter and no way back. Now an app bar back arrow, "Enter the code", "Sent to +33 6 12 34 56 78" with a "Change" button, a focused code field with the keyboard up, Verify, and a disabled "Resend code in 26 s". The "We texted you a 6-digit code" line is gone | Fixed. The disabled resend label is pale (D5) |
| `05_phone_verify_in_flight` | Code typed, "Verifying…" with spinner, field read-only, resend disabled, keyboard dismissed by the freeze. At the small phone / xxl the spinner is built but scrolled off screen | Fixed at default size; D6 at xxl |
| `06_phone_verify_error` | Was the generic sentence under the buttons (and impossible to photograph at xxl). Now "That code didn't work. Check it or resend." on the field in `dangerText`, field cleared and refocused, countdown still running. Exists at xxl now (see below) | Fixed |
| `07_phone_verify_resent` (new) | After the 30 s cooldown "Resend code" is tapped: "Code sent again" under the resend button, countdown restarted at about 26 s | New, as designed |
| `10_age_gate` | Same content, now inside a scroll view (still centred when it fits). At the small phone / xxl the title and button no longer overflow (45 px bottom overflow before) | Fixed |
| `11_age_gate_picker` | Opens on the year grid with "Your date of birth" as the help text (was the calendar on October of the default year with the generic "Select date"); the default year is highlighted | Fixed |
| `12_age_gate_under18_selected` | Unchanged layout ("9 October 2016", Continue enabled) | Unchanged |
| `13_signin_underage_notice` (new) | After the under-18 Continue the user lands on sign-in with a peach card "You must be 18 or older to use Convyve." and a 48 pt close button. Before, the user was dropped on a plain sign-in screen without explanation | Fixed |
| `14_profile_setup_empty` | Subtitle is one short line, "Name, photo and gender. That's it." (was two lines). The add-photo tile now says "Add photo" under a dark icon. "Still needed: a photo, your name and how you identify." under the disabled Continue | Fixed |
| `15_profile_setup_filled` | Keyboard up with the Bio caret: the form is scrolled so Name, gender, Bio and Continue are above the keyboard (Continue sits right on top of it, the "Still needed" line is below the fold) | Fixed |
| `16_profile_setup_ready` | Photo added by the admin write; the typed name and bio survive (`UXCHECK router: ... true`), Continue is coral and enabled and visible above the keyboard, the hint is gone | Fixed |

Dark (`17a-dark-default`): same layouts. Apple's button is white with a black glyph on the dark page, the field error, banner and the "Still needed" line keep readable colours, the disabled Verify/Resend and Continue are low-contrast greys as for every disabled button. No dark-specific defect found.

## Small phone, `accessibility-extra-large` (se3-light-xxl; BEFORE = 2026-10-06)

| Shot | Before | After |
|---|---|---|
| `01_signin` | Both provider buttons overflowed the screen by 83 and 107 px ("Continue with Go…", red/yellow overflow stripes) | Title and subtitle wrap; the Google button wraps its label onto two lines inside a taller button; the Apple button fits, "Continue with Apple" fully visible at 375 pt and not clipped. No overflow lines for 01, 03, 10 in `se3-light-xxl.findings.txt` (the earlier 191 px at 03 and 45 px at 10 are gone) |
| `03_signin_phone_waiting` | no indicator | "Sending code…" spinner, button wraps to two lines, Apple dimmed |
| `04`/`05_phone_verify*` | `05` could not be tapped (Verify behind the keyboard / off screen, `UXMISSING`) | The 6th digit submits without Verify; `05` is photographed with the code in the field. Verify/spinner itself is off screen (D6) |
| `06_phone_verify_error` | Did not exist | Exists. The cleared field with the cursor is above the keyboard; the error line and Verify are under the keyboard until the user scrolls (D7) |
| `10_age_gate` | Overflowed 45 px at the bottom (Continue cut by stripes) | Scrolls, no overflow |
| `13_signin_underage_notice` | n/a | Banner wraps to three lines with a 48 pt close button, rest of the sign-in screen below |
| `14_profile_setup_empty` | n/a | "Add photo" label scales down inside the tile and does not overflow; Name field and the rest scroll |

Apple button label at the small phone: checked, fully visible (a single line at 375 pt, 24 px SF Pro). 320 pt (iPhone SE 1st gen, not available) stays on the manual list (`docs/TEST-PLAN.md`).

## Remaining defects

| # | Defect | Severity | Owner |
|---|---|---|---|
| D1 | Official multicolour Google "G" mark: the sign-in button still uses the Material `g_mobiledata_rounded` stand-in (also tiny at xxl). Needs Google's brand asset added to the repo, then a small widget swap | P3 (brand, may block store review) | open item for 19 / an asset task, not 17b |
| D2 | Android phone auto-verification: `verificationCompleted` signs in with `signInWithCredential` (not awaited, errors unhandled) and never tells the screen; the sign-in spinner stays until the router leaves, or for 60 s if the sign-in fails. Not visible in this capture (iOS) | P2 | 18 (settings/auth hardening) or a small auth follow-up |
| D3 | Apple's label is 24 px next to the 16 px Google/Send code labels: the two provider buttons look unbalanced. Fixed by the package (0.43 x height); would need a smaller button height, which Apple allows | P3 | follow-up with D1 |
| D4 | Send code (and the error) are partly behind the keyboard in `02` at default size | P3 | follow-up (sign-in `scrollPadding`) |
| D5 | Disabled "Resend code in N s" is a pale grey on cream (below 3:1; disabled text is exempt from WCAG, but readers want to see the countdown) | P3 | follow-up |
| D6 | xxl small phone: the Verifying… spinner and button are scrolled off screen in `05`; the user gets no visible progress | P2 | follow-up (scroll the button into view on submit) |
| D7 | xxl small phone: the wrong-code message and Verify are under the keyboard after a failure (`06`); the field has the focus and the message is in a live region, so screen reader users hear it | P2 | follow-up (`scrollPadding` on the code field) |
| D8 | Discover, meal detail, requests, chat, report/rating sheets still overflow at xxl on the small phone: Paris notice 192 px right (`24`), meal detail 192 px (`40`, `44`-`46`, `49`), post-meal / chat error cards 55 px bottom, report sheet 11 px, rating sheet 118 px, `20_discover_loading` 13 px; the chat send / report Submit / rating Submit in-flight shots are `UXMISSING` | P1 | 17b (Discover, meal detail), 18 (requests, chat, ratings, settings) |
| D9 | Create meal / restaurant search cannot be captured (Places secret), and `33_create_meal_empty` overflows 2.2 px at xxl | P3 | harness follow-up; 17b (create meal) for the overflow |
| D10 | All new strings ("Still needed…", "Code sent again", the banner, …) are English only | P2 | 19 (French) |

## Not verified by the capture

- VoiceOver announcements of `AppButton` idle to loading, the "Uploading photo" and "Signing in…" nodes, live regions: manual step in `docs/TEST-PLAN.md`.
- Real Apple sign-in sheet, real Google sign-in, real SMS and the Android auto-verification path (code reading only, see D2).
- The photo picker (native); the add-photo tile is photographed idle only. Focusing fields scrolling Continue into view on a real keyboard on a device: manual step.
