# UX plan 18: verification capture

Plan 18 (request inbox, chat, report/rating/block sheets, Settings and Blocked people, profile) checked on the real app. Simulators "Convyve E2E" (iPhone 17 Pro, 402x874 pt) and "Convyve UX Small" (iPhone SE 3rd gen, 375x667 pt).
BEFORE = `ux_audit/out/17b-light-default/` (the 17b app, iPhone 17 Pro) and, for the small phone at `accessibility-extra-large`, the 17b `se3-light-xxl` cell (6 `UXOVERFLOW` findings, log kept). AFTER = `18-light-default`, `18-dark-default` and `se3-light-xxl` re-run with `tool/ux_matrix.sh --only se3-light-xxl`.
Seed times and the status-bar clock differ between runs (the seed is relative to "now"): compare structure only. Both simulators were put back to light / `large` afterwards. Eight downscaled AFTER shots are in `docs/ux/shots-18/`.

## Harness changes (`ux_audit/`, README updated)

- **The world seed was stale (fixed here).** Since the privacy split (`users/{uid}` private, `profiles/{uid}` public) the app merges both docs, but `support/world.dart` still wrote name, photos, bio and rating on `users/{uid}` only, so the viewer never left the profile-setup screen and every step after sign-in failed (first attempt: 9 of 68 shots). `seedUsers` now writes both docs; the onboarding photo step writes `profiles/{uid}`.
- New shots (73 per cell now, 68 before): `76_chat_safety_sheet`, `82_profile_edited`, `82b_profile_name_blank`, `84_settings_bottom`, `86_blocked_people` (the seeded block of Hugo), `87_blocked_people_empty` (after a real Unblock). `83_settings` is the top of the list; `63`/`64` show the meal header, banner and day separators, `72` the post-meal card.
- `61_chats_empty` waits for the new "Find a meal" button (the copy changed). `72_chat_post_meal_card` scrolls the thread up until the card is built (at large text on the small phone the card sits above the oldest message, a lazy list item).
- `55_requests_deny_in_flight` no longer demands a spinner: a denied request leaves the inbox at once (optimistic write), so there is no row left; the shot was already an empty inbox at 17b. The Deny "Denying…" state is widget-tested.
- `93_discover_error` is skipped with a `UXNOTE`, not failed: develop's "skip unparseable meals" change means a malformed meal no longer makes Discover fail, and there is no other way to make the feed fail without changing the app. 73 shots = 68 + 6 new - 1.
- Capture environment: the native "Would Like to Send You Notifications" alert covered the first attempt (together with the stale seed); `xcrun simctl shutdown/boot` of "Convyve E2E" and a re-run fixed that part. A stray first run was killed together with its emulators; no processes of this task remain.

## Per shot (default size, light unless noted)

| Shot | What changed | Verdict |
|---|---|---|
| `52_requests_data` | Approve is a big coral button, Deny a quiet brick-red text button; each guest has a star rating under the name; the tab icon is an inbox (with the count badge) instead of the mail-with-dot | Fixed (REQ-01/04/05) |
| `53_requests_scrolled` | Same tiles; the past-meal chip and its disabled Approve still read clearly | Fixed |
| `54_requests_approve_in_flight` | The spinner and "Approving…" are only in Dario's Approve; Dario's Deny is dimmed; the other tiles' buttons stay at full strength | Fixed (REQ-02) |
| `55_requests_deny_in_flight` | Empty inbox (the row is removed optimistically); no in-flight Deny state can be photographed | Unchanged (harness limit, see above) |
| `61_chats_empty` | "No chats yet", "Match on a meal to start talking." and a coral "Find a meal" button (was text only) | Fixed |
| `62_chats_data` | A muted meal line under each name ("Le Comptoir du Relais · Tomorrow 20:00"); the unread dot has a name for screen readers | Fixed (CHATS-01/02) |
| `63_chat_messages` | The thread starts under a meal header ("restaurant · date", chevron, tap opens the meal) and a one-line safety banner with a dismiss X, instead of the tall tips card that covered the top of the screen; "Today" separator between days; the time shows only under the last bubble of a burst | Fixed (CHAT-01/02/03/05/06) |
| `64_chat_messages_older` | More messages fit; the banner and header stay; grouped bubbles | Fixed |
| `65_chat_empty` | Header and banner above "Say hi" (the card used to push it down) | Fixed |
| `66_chat_send_pending` | Unchanged spinner on send; the composer clears at once and the text returns if the send fails (widget-tested) | Fixed (CHAT-06) |
| `76_chat_safety_sheet` (new) | Tapping the banner opens a bottom sheet with the four tips and "Got it" | New |
| `68_chat_report_sheet` | Titled "Report Bastien Marchetti" (was "Report"); the note box has a visible edge; chips unchanged in size | Fixed (REPORT-) |
| `69_chat_report_filled` | The selected reason chip label is dark on coral and readable (it measured 2.5:1 before) | Fixed |
| `71_chat_block_dialog` | "Block Bastien Marchetti?" and a brick-red "Block" button (the name used to be missing and the confirm looked like Cancel) | Fixed |
| `72_chat_post_meal_card` | The rating prompt is a compact card just above the composer ("How was your meal?" / "It only takes a moment." / "Rate Giulia Pellegrini") instead of a card pinned at the top with the tips card under it; it scrolls with the messages | Fixed (RATE-04) |
| `73_rating_sheet` | "How was your meal with Giulia Pellegrini?"; stars are visible outlines; the comment box has an edge | Fixed (RATE-) |
| `74_rating_sheet_filled` | Selected stars are filled dark (shape plus colour) | Fixed |
| `80_profile_edit` | Title "Profile" (was "Edit profile"), "Your rating 4.7 (7)" row, Save dimmed because nothing changed | Fixed |
| `82_profile_edited` (new) | One letter typed: Save is coral and enabled | New |
| `82b_profile_name_blank` (new) | Name cleared: Save dimmed and "Still needed: your name." under it | New |
| `83_settings` / `84_settings_bottom` (new) | Grouped under small headers: Account, Safety (Blocked people, Safety tips, Contact support), Notifications, Legal (with Open-source licences), About; Delete account last in red. No Phone row: the seeded viewer signs in without a phone number | Fixed (SET-) |
| `85_settings_delete_dialog` | Unchanged dialog over the new list | Unchanged |
| `86_blocked_people` (new) | One row: avatar, "Hugo Thibault", outlined Unblock | New. The row is plain (no subtitle); P3 |
| `87_blocked_people_empty` (new) | After a real Unblock: block icon, "You haven't blocked anyone", "People you block are hidden from your meals and chats." | New |

Dark (`18-dark-default`): same layouts; checked `52`, `72`, `73`. Approve keeps its coral fill with a dark label, Deny is a readable salmon, the sheet fields and stars keep a visible edge, banner and header are muted but legible. No dark-specific defect found. Not viewed one by one: the rest of the dark cell.

## Small phone, `accessibility-extra-large` (se3-light-xxl)

`UXOVERFLOW` lines: 6 before, 0 after.

| Before (17b) | After |
|---|---|
| `63_chat_messages` 55 px (tips card) | Gone: the banner is one row that wraps to two lines |
| `65_chat_empty` 55 px | Gone |
| `72_chat_post_meal_card` 55 px | Gone (card is laid out as a column at this size and scrolls) |
| `90_chat_error` 55 px | Gone |
| `68_chat_report_sheet` 11 px | Gone |
| `73_rating_sheet` 118 px | Gone (the sheet scrolls) |

No remaining overflow stripes, no failed steps, no missing indicator in this cell. What still looks poor at this size (not overflows):

- `63`/`65`/`72`: with the meal header (one line, ellipsized to "Le Comptoir du ..." so the time is cut off) and the two-line safety banner above a 2.0x composer, only about a third of the screen is left for messages. The header is tappable and the banner can be dismissed, so nothing is lost, but the first impression is crowded. P3. Owner: later polish (short banner label or wrap the header at large text).
- `72`: the post-meal card sits above the oldest message at this size (a lazy list item), so a long thread buries the rating prompt; the "Rate Giulia Pellegrini" button is only half visible above the composer in the still photo. P2. Owner: follow-up (pin the prompt in the header area, or surface it on the Chats list).
- `52`: at 2.0x one request tile is taller than the screen (the name wraps to four lines); Approve and Deny are one scroll below the name. P3. Owner: later polish.
- `86`: Unblock drops below the name and is full width, as designed (above 1.3x text).

## Remaining defects and follow-ups

| Item | Severity | Owner |
|---|---|---|
| Language row in Settings; French copy | P3 | Plan 19 (French / language switch) |
| A typed `createRequest` failure so "This meal is no longer open." can show (today every failure reads "Couldn't send your request.") | P3 | Follow-up (repository + `MealActionBar`) |
| `settleOrQueue` gives up waiting after 3 s, which can hide a slow server rejection behind a success | P2 | Follow-up (offline writes) |
| Live meal stream: a meal cancelled while its detail screen is open does not change to "Meal cancelled" until reopened | P3 | Follow-up (`watchMeal`) |
| "Meal ended" state for a completed meal without a request (the bar still offers Request to join) | P3 | Follow-up |
| Notices (snackbars: approved, denied, unblocked) are not persisted, so they are lost if the screen is left | P3 | Follow-up (notice persistence) |
| Google "G" mark asset on the sign-in button | P3 | Follow-up (asset) |
| Android phone auto-verification (direct user switch, no signed-out state) | P3 | Follow-up (Android) |
| Android notification settings row (needs an Android settings intent, so a package) | P3 | Follow-up (Android) |
| Deny keeps `onSurface` (not brick red) while loading | P3 | Follow-up (`AppButton`) |
| `RatingBadge` has no semantics label (the star and "4.7 (7)" read as separate pieces) | P3 | Follow-up (app-wide) |
| Inbox re-entrancy guard (a double tap can start two writes for one request) | P3 | Follow-up |
| `93_discover_error` can no longer be produced by the harness (Discover skips malformed meals) | P3 (tooling) | Harness follow-up (needs an injectable failing feed) |
| Crowded chat top at 2.0x on a 375 x 667 phone; post-meal prompt buried in long threads | P3 / P2 | See the small-phone section |

Widget-tested only (not seen in the capture): the Settings licence page, the iOS notification row opening Settings (the seeded sign-in has no phone and the capture does not tap external links), the Phone row, "Meal cancelled" on meal detail, loading labels spoken by VoiceOver, the Blocked-people loading skeleton and error state.
