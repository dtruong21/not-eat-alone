# UX plan 16b: verification capture

Plan 16b (shared `AppButton` / `ErrorState` / `EmptyState` / skeletons, one stable router, Paris date formats) checked on the real app, simulator "Convyve E2E" (iPhone 17 Pro), default text size.
BEFORE = `ux_audit/out/16a-{light,dark}-default/`, AFTER = `make ux-capture ... OUT=16b-light-default` and `OUT=16b-dark-default` (65 shots each, none blank; local only, not committed). Selected AFTER shots (downscaled): `docs/ux/shots-16b/`.
Seed times differ between runs (status-bar clock, "tonight"), compare structure only.

Harness notes (the harness changed with the app, `ux_audit/capture_test.dart`):
- It looked for a spinner in the Discover and chat-list loading shots and for the old error sentence in the 90-93 shots; it now looks for `SkeletonList` and "Couldn't load this". A first light run with the old expectations produced the PNGs but logged failed steps (kept locally as `16b-light-run1`, not used).
- The step after the women-only shot (46) signs in as another user and relied on the old router reset to get back to Discover. With the stable router the pushed detail route stays, so that step now calls `_recover`. The light capture (`16b-light-default`) was taken before this fix: its 65 PNGs are complete but the run ended with one failed step (`errors_viewer_signin`, no PNG of its own; shots 90-93 are fine). The dark run, with the final harness, is clean (`UXSUMMARY failedSteps=0`, `make` exit 0).

## Per shot

| Shot | What changed | Verdict |
|---|---|---|
| `20_discover_loading` (light, dark) | Was a lone spinner; now three skeleton cards (avatar + three lines, shimmer) under the Paris notice, same card shape/shadow as the data. Dark: blocks are a small step from the card. | Fixed |
| `22_discover_data` | Dates were "October 6, 2026 at 8:30 PM"; now "Today 20:30", "Wed 14 Oct, 20:00", "Sun 11 Oct, 17:00" (24 h, day before month). | Fixed |
| `52_requests_data` | Request times read "Sun 11 Oct, 19:30" in the same format; a past meal reads "Thu 8 Oct, 04:52" (absolute for past dates). Layout unchanged. | Fixed |
| `62_chats_data` / `63_chat_messages` | Message times are 24 h ("08:52", "06:54"); chat list unchanged. Light and dark. | Fixed |
| `60_chats_loading` | Skeleton list (avatar + lines) instead of a spinner. | Fixed |
| `93_discover_error` (light, dark) | "Something went wrong" line replaced by a cloud-off icon, "Couldn't load this", "Check your connection and try again." and a tonal **Try again** button (56 high). Title in the normal text colour, body and icon muted. | Fixed (D1) |
| `90_chat_error`, `91_requests_error`, `92_chats_error` | Same ErrorState in the chat message area, requests inbox and chat list. In 90 the safety card and composer stay on screen around it. | Fixed (see D4 below) |
| `05_phone_verify_in_flight`, `37_create_meal_in_flight`, `70_chat_report_in_flight`, `75_rating_sheet_in_flight` | Button keeps its coral fill, shows a dark spinner and the loading label ("Verifying...", "Creating...", "Submitting...") at the same position and size as the idle button (size equality is also widget-tested at 2.0x text). The spinner in the PNG is a short arc: the photograph catches the indeterminate spinner at the start of its cycle (same as 16a); the darker centre band is the tap ripple. | Fixed |
| Profile setup (`15` -> `16_profile_setup_ready`) | The admin write adds a photo while the form is filled in. Before: the router rebuilt and the form emptied (the harness typed it in again). Now the harness checks first and logs `UXCHECK router: profile form kept its input after a user-doc write: true` in BOTH the light and the dark run: the name field kept its text and the screen stayed where it was. | Fixed (X-09), seen end to end |

Router fix, honestly: this is the only navigation check the harness can make (a user-doc write while a screen is open). It does not tap "Save" on the profile edit screen (profile Save is not captured, see the README "Not captured"), so "editing the profile photo from the profile tab no longer returns to Discover" is covered by the router widget tests (`test/core/routing/router_stability_test.dart`: same router instance and a TextField keeping its text across a user-doc change), not by a photographed step. Side effect found by the capture: a pushed route now survives a sign-in as another user (the harness relied on the old reset); a direct user A to user B switch (Android phone auto-verification, no signed-out state) is now handled by the router's uid listener (`router.go('/discover')`, test-covered); only a sign-out/sign-in with no frame between is test-only (sign-out goes through the router redirect). The same effect broke three E2E scenarios that switch users on a mounted app (rating, request/match, chat): fixed in the tests with `signOutAndAwaitSignIn`.

## Remaining defects (not 16b scope)

| # | Defect | Severity | Owner |
|---|---|---|---|
| R1 | Sign-in "Phone number" floating label overlaps the field edge; Google/Apple buttons are 48 high next to the 56 "Send code"; sign-in phone error (`02`) is still a bare red line, not the shared pattern | P3 | 17 (onboarding) |
| R2 | Discover: the Paris notice has the same surface as the cards (no hierarchy); the FAB covers card content when scrolled | P2 | 17 (Discover) |
| R3 | Meal detail: sparse layout; disabled buttons ("Requested", "Not selected") are 48 high, the idle one 56 | P2 | 17 (meal detail) |
| R4 | Chat: the message list is clipped under the safety card (63); the composer looks like a plain bar; on a failed message load (90) the composer stays enabled under the error | P2 | 18 (chat) |
| R5 | Requests: "Meal time has passed" chip is a low-emphasis pink on the peach card; no "which meal" headline hierarchy | P2 | 18 (requests) |
| R6 | Settings: still a short plain list | P2 | 18 (settings) |
| R7 | Chat list shows relative ages ("1h", "3d") while meals show absolute dates; ratings flow not re-checked | P3 | 18 |
| R8 | All dates, labels and the new error/empty strings are English only; format code is dependency-free until `intl` | P2 | 19 (French) |
| R9 | Dark skeleton blocks are only a small step from the card surface (the shimmer sweep adds contrast in motion, not in a still photo) | P3 | 17 (with Discover polish) |
| R10 | Large text (xxl) overflows and keyboard-obscured actions (X-10) were not re-captured in 16b (default size only) | P1 | 17 / 18 per screen |

## What is test-guarded (see `docs/TEST-PLAN.md`)

AppButton variants, loading look, tap swallow, size stability; ErrorState/EmptyState/skeleton rendering, semantics (live region, "Loading"), light/dark colours, 2.0x text, shimmer on/off and highlight contrast; the feed screens' skeleton/error/Try again; router identity and redirects; date formats (also under `TZ=Pacific/Kiritimati`). Only seen in the capture: how it looks, the in-flight appearance, and the profile-setup form keeping its text through a user-doc write.
