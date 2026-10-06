# Convyve UX audit (Plan 15, Part A, Task 3)

**Date:** 2026-10-06 · **Branch:** `feature/ux-pass` · **Author:** ux-designer
**Inputs:** `docs/superpowers/specs/2026-10-05-ux-pass-design.md` §2.2/§3, `docs/ux/OWNER-FEEDBACK.md`, `docs/ux/contrast-measured.txt`, `docs/DESIGN.md`, `lib/core/design/{tokens,theme}.dart`, `ux_audit/README.md`, every presentation file under `lib/features/*/presentation/`, and the 8-cell capture matrix in `ux_audit/out/`.

Shot references use `shots/<cell>__<NN_name>.png` (source: `ux_audit/out/<cell>/<NN_name>.png`, listed in `docs/ux/AUDIT-SHOTS.txt`). Cells: `iphone17-{light,dark}-{default,xxl}`, `se3-{light,dark}-{default,xxl}`. Shorthand `__NN_name.png` or `__NN` in a cell means the same cell as the last full reference in that cell, and `iphone17-light-default` when there is none.

Severity: **P0** broken or unreadable · **P1** clear UX problem · **P2** polish. Effort: **S** < half a day · **M** 1-2 days · **L** > 2 days.

Design direction is kept (Warm Playful). Where the palette itself cannot reach WCAG AA, the fix is a token change, stated with numbers. Ratios marked "(hand-computed)" are mine, computed from the hex values with the WCAG formula; they must be locked by the contrast test proposed in B1-6.

---

## (a) Summary

### Findings per screen

| Screen | P0 | P1 | P2 |
|---|---|---|---|
| Sign-in | 0 | 5 | 2 |
| Phone verify | 1 | 3 | 1 |
| Age gate (+ under-18) | 0 | 3 | 2 |
| Profile setup | 0 | 3 | 2 |
| Discover | 0 | 4 | 3 |
| Restaurant search | 0 | 0 | 2 |
| Create meal | 0 | 1 | 3 |
| Meal detail | 0 | 4 | 5 |
| Requests inbox | 0 | 3 | 3 |
| Chats list | 0 | 0 | 2 |
| Chat | 1 | 3 | 3 |
| Report sheet + block | 1 | 1 | 2 |
| Rating sheet + post-meal card | 0 | 2 | 2 |
| Profile edit | 0 | 2 | 2 |
| Settings | 0 | 1 | 2 |
| Error states (90-93) | 0 | 1 | 0 |
| **Cross-cutting (section c)** | **1** | **9** | **3** |
| **Total** | **4** | **45** | **39** |

Cross-cutting rows that only summarise per-screen findings (X-10 large text, X-11 tap targets, X-16 state matrix) carry no count of their own, so nothing is counted twice.

The single biggest problem is cross-cutting and P0: **all secondary text is drawn in the border colour** (`colorScheme.outline`, 1.15-1.22:1 in light, 1.22-1.36:1 in dark). It is counted once, as X-01, not once per screen, although it appears on 14 of the 16 screens.

### Top 10: what to fix first

| # | Fix | Closes | Effort |
|---|---|---|---|
| 1 | Secondary text: replace all 27 `colorScheme.outline` text uses with `wp.muted`, darken light `muted` to `#7A6352` (5.1:1 on surface), map `onSurfaceVariant` to it, and forbid `outline` as a text colour by test | X-01, owner ask 1, ~25 per-screen mentions | M |
| 2 | Button system: `FilledButton` = primary (coral fill, brown label); `onPrimary` = brown in both modes; spinners use the button foreground; one shared `AppButton` with `isLoading` | X-02, X-03, AGE-01, REQ-01, REPORT-02, RATE-02, owner asks 2-3 | M |
| 3 | Chat at large text and with keyboard: collapse the safety card to a one-line, dismissible banner and make the message list the only flexible child | CHAT-01 (P0), CHAT-02 (owner) | M |
| 4 | Sheets and fixed forms scroll with the keyboard: report/rating sheets as `SingleChildScrollView` + `viewInsets`, phone-verify and age gate scrollable | REPORT-01 (P0), VERIFY-01 (P0), RATE-01, AGE-03, SIGNIN-02 | M |
| 5 | Meal detail action bar: one pinned, full-width, 56 pt action area whose size never changes across idle / sending / requested / matched / not selected / women-only / own | MEAL-01..03, owner ask 2 | M |
| 6 | Error states: one `ErrorState` widget (icon, human sentence, Retry) for the 4 feeds + meal detail + search; verify (and if needed fix) that a rejected join request surfaces a message | X-07, MEAL-04, owner ask 3 | S-M |
| 7 | Loading pattern: skeleton cards for Discover/Requests/Chats/messages, spinner inside the pressed button only, Send-code spinner held until the code screen | X-06, SIGNIN-03, REQ-02, owner ask 3 | M-L |
| 8 | Error and destructive text token: `dangerText` light `#A84A35` (5.5:1 on bg, hand-computed); coral is for fills, never for body text on cream | X-04 | S |
| 9 | Bundle Nunito as an asset and apply it through `ThemeData(fontFamily:)`; drop the runtime `google_fonts` fetch | X-05 | S |
| 10 | Router: stop rebuilding `GoRouter` on every `users/{uid}` change (derive redirect inputs through `refreshListenable`), so photo upload / profile save no longer reset navigation | X-09, SETUP-02 | M |

---

## Owner asks, answered

### 1. "Light mode is too bright; secondary info is unreadable" (dark not yet reviewed)

**Confirmed, and the cause is precise.** Secondary text (dates, times, distances, addresses, bios, chat timestamps, "Seen", empty-state copy, sub-headings, settings section headers) is coloured `colorScheme.outline`, which `theme.dart:62` sets to the **border** token `#F0E2D2`. Border is meant for 1 px lines, not text: it measures **1.22:1 on bg and 1.15:1 on surface** (needs 4.5:1). Evidence: `shots/iphone17-light-default__22_discover_data.png` (date and km lines are near invisible), `shots/iphone17-light-default__40_meal_detail_open.png` (address, host bio), `shots/iphone17-light-default__63_chat_messages.png` (timestamps, "Seen"), `shots/iphone17-light-default__62_chats_data.png` (preview, "1h"), `shots/iphone17-light-default__83_settings.png` (section headers).

"Too bright" is two things, both measured:
- the text problem above (the main cause), and
- surfaces barely separate: cards (`surface #FFF1E6`) on the page (`bg #FFFAF3`) are **1.07:1** (hand-computed), so cards, inputs and buttons are only faintly distinguishable from the cream page (visible, but weak) and the screen reads as one bright wash (`shots/iphone17-light-default__31_restaurant_search_no_matches.png`, `shots/iphone17-light-default__22_discover_data.png`).

The palette has a token that almost works: `muted #8C7563` is 4.18:1 on bg and **3.92:1 on surface**, just short. Fix (B1-1): darken light `muted` to **`#7A6352`** (5.42:1 on bg, 5.08:1 on surface, hand-computed), use `wp.muted` for all secondary text, and give cards definition: either the soft shadow DESIGN.md already specifies (`Color(0x0F3D2E1F)`, blur 12, y 4; currently `CardTheme.elevation: 0`, no shadow) or a slightly deeper `surface #FBE8D8` (1.15:1 vs bg; the new muted on it 4.72:1, text on it 10.96:1, hand-computed). The surface tweak is a brand-level change: **owner sign-off**. A shadow cannot be applied through `CardThemeData` alone: Discover cards, chat-list tiles, restaurant rows, the composer and the add-photo tile are built as `Material(color: colors.surface)`, not `Card`, so the theme's shadow would not reach them. Either introduce one shared surface widget (`AppSurface`) and use it at those sites, or edit each site.

**Dark parity:** the same failure exists in dark (border on surface 1.22:1, on bg 1.36:1): `shots/iphone17-dark-default__22_discover_data.png`, `shots/iphone17-dark-default__40_meal_detail_open.png`, `shots/iphone17-dark-default__63_chat_messages.png`. Dark `muted #B5A18C` already passes (6.26:1 on surface), so the same code change fixes both modes. Dark has two failures of its own: cream text on coral is **1.91:1** (selected report chip `shots/iphone17-dark-default__69_chat_report_filled.png`, selected day in the date picker `shots/iphone17-dark-default__11_age_gate_picker.png`) and two seed-derived colours are off-palette and glaring (the teal "Matched!" banner `shots/iphone17-dark-default__43_meal_detail_matched.png`, the deep red "Meal time has passed" chip `shots/iphone17-dark-default__52_requests_data.png`). Coral text on dark bg passes (8.75:1), so dark mode is actually *more* readable than light for coral labels. See X-08.

### 2. "Request to join" needs rework on size

**Confirmed: the button is the wrong weight and changes size between states.** Evidence: idle `shots/iphone17-light-default__40_meal_detail_open.png`, requested `shots/iphone17-light-default__42_meal_detail_requested.png`, matched `shots/iphone17-light-default__43_meal_detail_matched.png`, not selected `shots/iphone17-light-default__44_meal_detail_not_selected.png`, women-only `shots/iphone17-light-default__46_meal_detail_women_only_disabled.png`, own meal `shots/iphone17-light-default__48_meal_detail_own.png`.

- **Weight:** the idle button is a `FilledButton`, which the theme fills with `surface` (`theme.dart:186-199`). Peach on cream is ~1.07:1, so the app's single most important action looks like an inert panel; the disabled grey "Not selected" button looks more like a button than the enabled one.
- **Size:** idle and "Not selected" are full width (the parent `Column` stretches them); "Requested" and the women-only state wrap the button in a centered `Column` (`meal_detail_screen.dart:431`, `:543`), so it shrinks to its label and the label touches the edges (42, 46). "Matched!" is a taller teal banner (43), "Your meal" a small faint pill (48). Five states, four sizes.
- **Position:** it sits at the end of the scroll content, so a long note or bio, or large text, pushes it below the fold (`shots/iphone17-light-xxl__40_meal_detail_open.png`: not visible on the first screen).
- **In flight:** never visible. The write is applied locally and the button swaps to "Requested" in the same frame. A server rejection swaps it back; whether an error is shown is unverified (MEAL-04).

Spec for the rework is MEAL-01 (one pinned action bar, fixed 56 pt height, full width, state shown by label + style, never by size).

### 3. "Too few progress indicators"

**Confirmed. Full inventory in X-06.** Of 27 async actions/loads, 13 have a working indicator (mostly a bare centered spinner), 9 have one that is invisible, ends too early or is never rendered (cream spinner on a disabled grey button: `shots/iphone17-light-default__05_phone_verify_in_flight.png`, `__37_create_meal_in_flight.png`, `__70_chat_report_in_flight.png`, `__75_rating_sheet_in_flight.png`; Send code stops before the code arrives, `__03_signin_phone_waiting.png`), 4 have none (Approve/Deny `__54_requests_approve_in_flight.png`, sign out, block, row data such as avatars and rating badges), and 1 is unverified (rejected join request, MEAL-04). One pattern is proposed: skeleton cards for lists, the spinner inside the pressed button only (same size, readable colour), pull-to-refresh on Discover plus a Retry on every error state.

### 4. "Settings should be developed further"

Today (`shots/iphone17-light-default__83_settings.png`): Legal (Privacy, Terms), Account (Sign out, Delete account), About (Version). A structure is proposed in SET-04 with every item classed **exists today / backend exists, needs UI / new scope: owner decision**, sized and justified against MVP-first. Short version: reorder (Account first), add **Edit profile** and **Blocked users** (block data exists, no way to undo a block today), **Safety tips** and **Contact / report a problem** (mailto, no backend); Notifications toggles, phone change and language are **new scope** and default to CUT.

---

## (b) Per screen

Common to all screens and not repeated below: X-01 (secondary text), X-02 (primary buttons look inert), X-05 (font). Line numbers refer to the files as of commit `4c113e1`.

### 1. Sign-in (`lib/features/auth/presentation/signin_screen.dart`)

**Works:** clear three-way choice, `+33` prefill for a Paris launch, spinner per method in code, one method in flight at a time, title in Nunito.

| ID | Sev | Finding | Evidence | Cause | Fix | Effort |
|---|---|---|---|---|---|---|
| SIGNIN-01 | P1 | Google/Apple labels are coral on cream, **2.18:1** (fails 4.5). | `shots/iphone17-light-default__01_signin.png` | `OutlinedButton` is unthemed, so its foreground falls back to `colorScheme.primary` (`signin_screen.dart:273`) | Add `outlinedButtonThemeData` in `theme.dart`: foreground `onSurface`, side `wp.border` → 11.8:1 | S |
| SIGNIN-02 | P1 | At large text the auth buttons overflow 56-107 px to the right; labels clipped mid-word. | `shots/iphone17-light-xxl__01_signin.png`; logs `iphone17-light-xxl` and `se3-light-xxl` | `_AuthButton` builds a `Row(icon, Text)` with no `Flexible` (`:255-264`) | Wrap the label in `Flexible` with `textAlign: center`, allow 2 lines | S |
| SIGNIN-03 | P1 | "Send code": the spinner is gone as soon as the request is dispatched; for the seconds until the SMS screen appears nothing happens (only a ripple). | `shots/iphone17-light-default__03_signin_phone_waiting.png` | `finally { _pendingMethod = null }` runs when `verifyPhone` returns, before `codeSent` (`:114-115`) | Clear `_pendingMethod` in `codeSent`/`onError` only, with a 60 s safety timeout; label "Sending code…" | S |
| SIGNIN-04 | P1 | Phone error appears *under the keyboard*: only the top of the red line peeks above it. | `shots/iphone17-light-default__02_signin_phone_error.png` | error `Text` sits below the button in a scroll view that is not scrolled to it (`:203-210`) | Put the message on the field (`InputDecoration.errorText`), which the field keeps visible; copy: "Enter a phone number with country code, e.g. +33 6 12 34 56 78" | S |
| SIGNIN-05 | P1 | Store-review risk: the Google mark is `Icons.g_mobiledata_rounded` (a generic "G"), the Apple button is a coral outlined button. Apple's HIG requires an approved Sign in with Apple style; Google's branding guidelines require the official mark. | `shots/iphone17-light-default__01_signin.png` | `:151`, `:158` | Use `SignInWithAppleButton` (style black/white per brightness, from the already-installed `sign_in_with_apple`) and the official Google "G" asset on a neutral button | S |
| SIGNIN-06 | P2 | The phone field accepts any characters, has no autofill and no formatting. | `shots/iphone17-light-default__02_signin_phone_error.png` | `keyboardType: phone` only | `FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))`, `autofillHints: [AutofillHints.telephoneNumber]` | S |
| SIGNIN-07 | P2 | "or" divider label is border-coloured (X-01) and the subtitle "Sign in to get started." says nothing useful. | `shots/iphone17-light-default__01_signin.png` | `:146`, `:173` | Subtitle: "Meet one person over a meal in Paris." in `wp.muted` | S |

### 2. Phone verify (`lib/features/auth/presentation/phone_verify_screen.dart`)

**Works:** single field, numeric keyboard, `maxLength: 6`, generic error never leaks auth internals.

| ID | Sev | Finding | Evidence | Cause | Fix | Effort |
|---|---|---|---|---|---|---|
| VERIFY-01 | **P0** | At large text the screen does not scroll; the column overflows 99 px (191 px on SE) and **Verify ends up under the number pad**, which has no Done key. Phone sign-in cannot be completed (the capture could not even produce `06_phone_verify_error` at xxl). | `shots/iphone17-light-xxl__04_phone_verify.png`, `shots/iphone17-light-xxl__05_phone_verify_in_flight.png`; README "Last full matrix run" | `Padding > Column(mainAxisAlignment: center)` with no scroll (`:76-81`) | `SingleChildScrollView` + submit on 6th digit (`onChanged` length 6 → `_verify`) + `textInputAction: done` | S |
| VERIFY-02 | P1 | In-flight spinner is invisible: cream (`onPrimary`) on the disabled grey fill; only a tiny tick is visible. | `shots/iphone17-light-default__05_phone_verify_in_flight.png` | `:136-139` | X-03 (`AppButton` loading state) | S |
| VERIFY-03 | P1 | No way to change the number or resend the code; no visible back button (only the iOS edge swipe). If the SMS does not arrive the user is stuck. | `shots/iphone17-light-default__04_phone_verify.png` | screen has no `AppBar` (`:74`) | `AppBar` with back; line "Sent to +33 6 12…" + "Change"; "Resend code" `TextButton` enabled after 30 s (re-calls `verifyPhone`) | M |
| VERIFY-04 | P1 | A wrong code shows the generic "Something went wrong — please try again." in danger colour (2.84:1). | `shots/iphone17-light-default__06_phone_verify_error.png` | `:114-119` | Copy: "That code didn't work. Check it or resend." in `dangerText` (X-04); clear the field | S |
| VERIFY-05 | P2 | Subtitle "We texted you a 6-digit code." is unreadable (X-01) and does not show the number. | same | `:94` | see VERIFY-03 | S |

### 3. Age gate (`lib/features/onboarding/presentation/age_gate_screen.dart`)

**Works:** non-judgmental copy, one decision per screen, controller does the logic.

| ID | Sev | Finding | Evidence | Cause | Fix | Effort |
|---|---|---|---|---|---|---|
| AGE-01 | P1 | Inverted hierarchy: disabled "Continue" (grey) is more visible than enabled "Continue" (peach on cream, ~1.07:1). | `shots/iphone17-light-default__10_age_gate.png` vs `shots/iphone17-light-default__12_age_gate_under18_selected.png` | `filledButtonTheme` = surface (`theme.dart:186-199`) | X-02 | (X-02) |
| AGE-02 | P1 | DOB picker opens a month calendar on "October 2008"; reaching 1990 means the year dropdown or ~200 taps. Selected day is cream on coral (2.18 light, 1.91 dark). Title says "Select date", not "Date of birth". | `shots/iphone17-light-default__11_age_gate_picker.png`, `shots/iphone17-dark-default__11_age_gate_picker.png` | `showDatePicker` defaults (`:73-78`) | `initialDatePickerMode: DatePickerMode.year`, `helpText: 'Your date of birth'`, `fieldLabelText`; onPrimary fix (X-08) | S |
| AGE-03 | P1 | On SE at large text the column overflows 45 px and Continue is half off screen. | `shots/se3-light-xxl__10_age_gate.png` | non-scrolling `Column` (`:141-146`) | `SingleChildScrollView` + `ConstrainedBox(minHeight)` pattern | S |
| AGE-04 | P2 | The under-18 "blocked" screen is never shown (sign-out unmounts it first; README "Not captured"), so an under-18 user lands back on sign-in with no explanation. | not capturable; nearest `shots/iphone17-light-default__12_age_gate_under18_selected.png` | `age_gate_controller.dart` order: signOut before `blocked` | Show the blocked message *before* signing out (or as a sign-in banner on next frame). Needs a small controller change; verify with a widget test | S |
| AGE-05 | P2 | Subtitle "You must be 18 or older…" carries the rule and is unreadable (X-01). | `shots/iphone17-light-default__10_age_gate.png` | `:159` | X-01 | (X-01) |

### 4. Profile setup (`lib/features/onboarding/presentation/profile_setup_screen.dart`, `lib/features/user/presentation/widgets/profile_form.dart`)

**Works:** one form shared with edit, gender as a segmented control, counters on name and bio, no skip.

| ID | Sev | Finding | Evidence | Cause | Fix | Effort |
|---|---|---|---|---|---|---|
| SETUP-01 | P1 | The add-photo tile is a peach square with a 1.15:1 icon and no label; the only explanation that a photo is required is the unreadable subtitle. Continue stays disabled with no reason given. | `shots/iphone17-light-default__14_profile_setup_empty.png` | `profile_form.dart:384` (`outline` icon), `:363-388` | Tile: dashed `wp.muted` border, `Icons.add_a_photo_outlined` in `onSurface`, label "Add photo"; helper under Continue: "Add a photo, your name and how you identify" listing what is missing | S |
| SETUP-02 | P1 | Adding a photo rewrites `users/{uid}`, which rebuilds the router: the shots show the scroll position reset to the top and focus jumping back to Name (the Name text survives in the shot). The README reports the form emptying in another run; the shots do not show that, so treat data loss as unconfirmed (recapture with a bio typed to check). | `shots/iphone17-light-default__15_profile_setup_filled.png` → `shots/iphone17-light-default__16_profile_setup_ready.png` | `router.dart:116-120` watches `currentUserDocProvider` | X-09 | (X-09) |
| SETUP-03 | P1 | Photo remove "x" is 24×24 pt (needs 44). | `shots/iphone17-light-default__16_profile_setup_ready.png` | `profile_form.dart:335-346` `CircleAvatar(radius: 12)` in a bare `GestureDetector` | `IconButton` with `constraints: BoxConstraints.tightFor(44,44)` and a 24 visual, `tooltip: 'Remove photo'` | S |
| SETUP-04 | P2 | Bio and Continue end up under the keyboard while typing (no scroll-into-view of the button). | `shots/iphone17-light-default__15_profile_setup_filled.png` | — | Fine once X-02 makes the button findable; add `scrollPadding` | S |
| SETUP-05 | P2 | At large text the subtitle runs 5 lines and pushes photos below the fold. | `shots/iphone17-light-xxl__14_profile_setup_empty.png` | — | Shorter copy: "Name, photo and gender. That's it." | S |

### 5. Discover (`lib/features/meal/presentation/discovery_screen.dart`, `widgets/paris_notice.dart`)

**Works:** card per meal with restaurant, time, distance, host; women-only badge; pull-to-refresh (`shots/iphone17-light-default__25_discover_refreshing.png`); FAB to create; Paris fallback when location is denied.

| ID | Sev | Finding | Evidence | Cause | Fix | Effort |
|---|---|---|---|---|---|---|
| DISC-01 | P1 | Date/time and distance, the two facts that decide a tap, are unreadable (X-01) and take two lines in total (one each). | `shots/iphone17-light-default__22_discover_data.png`, `shots/iphone17-dark-default__22_discover_data.png` | `:229-237` | One line in `wp.muted` bodySmall: "Tonight 20:30 · 1.3 km" (relative day, see X-12) | S |
| DISC-02 | P1 | Paris notice is pinned above the list (outside the scroll view), takes ~10% of the viewport at default size (~39% at xxl), comes back every session, and its close button is 24×24 pt. | `shots/iphone17-light-default__23_discover_scrolled.png`, `shots/iphone17-light-xxl__22_discover_data.png` | `paris_notice.dart:57-71` (`minWidth/minHeight: 24`); not persisted (`_dismissed` only) | Make it the first list item (scrolls away), persist dismissal (`SharedPreferences` if present, else keep per-session but inside the list), 44 pt close `IconButton` | S |
| DISC-03 | P1 | The list has no bottom padding for the FAB, so the last card's content (date, host name) ends under the FAB when scrolled to the end. Code-only: the shots are mid-scroll and show the FAB over a card that can still scroll clear (`shots/se3-light-default__22_discover_data.png`); a scrolled-to-end recapture is needed in Part B verification. | `shots/se3-light-default__22_discover_data.png` (mid-scroll, context only) | `discovery_screen.dart:131` `ListView.separated(padding: all(s4))` | Bottom padding `s8 + s5` (88) on the list | S |
| DISC-04 | P1 | A one-tap, unconfirmed **Sign out** icon sits on the home app bar, where users expect profile or filters; re-entry costs an SMS. It duplicates Settings. | `shots/iphone17-light-default__22_discover_data.png` | `:160-166` | Remove it from Discover (Settings keeps Sign out, with a confirm dialog) | S |
| DISC-05 | P2 | Empty state is one faint line; DESIGN.md's `EmptyState` (illustration, title, subtitle, primary action) is not used. In a soft launch this is a likely first impression. | `shots/iphone17-light-default__21_discover_empty.png` | `:129` | `EmptyState` widget: emoji/illustration, "No meals nearby yet", "Be the first: host a meal and someone will join.", primary "Create a meal" | S |
| DISC-06 | P2 | Loading is a lone spinner under the notice. | `shots/iphone17-light-default__20_discover_loading.png` | `:123` | Skeleton cards (X-06) | (X-06) |
| DISC-07 | P2 | Large text: one card fills the screen; restaurant names wrap 4 lines. | `shots/iphone17-light-xxl__24_discover_notice_dismissed.png` | — | `maxLines: 2, overflow: ellipsis` on the name; date/distance on one line (DISC-01) | S |

### 6. Restaurant search (`lib/features/meal/presentation/restaurant_search_screen.dart`)

**Works:** search-as-you-type, clear rows, back navigation.

| ID | Sev | Finding | Evidence | Cause | Fix | Effort |
|---|---|---|---|---|---|---|
| SEARCH-01 | P2 | Addresses unreadable (X-01); "No matches" is faint and gives no next step. | `shots/iphone17-light-default__30_restaurant_search.png`, `shots/iphone17-light-default__31_restaurant_search_no_matches.png` | `:90`, `:179` | `wp.muted`; empty copy "No restaurant called “zzzz”. Try another name." | S |
| SEARCH-02 | P2 | Error and loading states exist in code but are the bare spinner / bare red text (could not be captured: in-memory fake). | not capturable | `:74-83` | Reuse `ErrorState` / skeleton rows (X-06, X-07) | S |

### 7. Create meal (`lib/features/meal/presentation/create_meal_screen.dart`)

**Works:** restaurant echoed at the top, single date-and-time button, 5-minute minimum lead with a clear snackbar, optional note with counter.

| ID | Sev | Finding | Evidence | Cause | Fix | Effort |
|---|---|---|---|---|---|---|
| CREATE-01 | P1 | "Create meal" in flight shows an invisible spinner on a grey disabled button; nothing tells the host it is working. | `shots/iphone17-light-default__37_create_meal_in_flight.png` | `:254-262` | X-03 | (X-03) |
| CREATE-02 | P2 | Time picker is a 24-hour dial (device locale) but the result is shown as "11:01 AM"; it defaults to "now + 1 h" to the minute (":01"). | `shots/iphone17-light-default__35_create_meal_time_picker.png`, `shots/iphone17-light-default__36_create_meal_filled.png` | `:77-80`, `date_format.dart:25-33` | Default to the next :00/:30; format times with the locale (X-12) | S |
| CREATE-03 | P2 | Date picker selected day is cream on coral (2.18:1). | `shots/iphone17-light-default__34_create_meal_date_picker.png` | `onPrimary` = cream (`theme.dart:54`) | X-08 | (X-08) |
| CREATE-04 | P2 | After creating, the user lands on Discover, which excludes their own meal; "Meal created!" covers the FAB and there is no way to find the meal again (README: no "my meals" list). | `shots/iphone17-light-default__26_discover_meal_created.png` | Discover filters own meals by design | Snackbar copy "Meal posted. You'll get requests in the Requests tab." (S). A "My meals" list is **new scope: owner decision** | S |

### 8. Meal detail (`lib/features/meal/presentation/meal_detail_screen.dart`)

**Works:** restaurant card, date in bold, note, host with age and rating, safety menu offering "Report this meal / Report host / Block host" before any match (`shots/iphone17-light-default__47_meal_detail_menu.png`), clear women-only guard for men.

| ID | Sev | Finding | Evidence | Cause | Fix | Effort |
|---|---|---|---|---|---|---|
| MEAL-01 | P1 | **Request to join (owner ask 2):** inert fill, size changes per state, at the end of the scroll content. Details in "Owner asks". | `shots/iphone17-light-default__40_meal_detail_open.png`, `__42_meal_detail_requested.png`, `__43_meal_detail_matched.png`, `__44_meal_detail_not_selected.png`, `__46_meal_detail_women_only_disabled.png`, `__48_meal_detail_own.png` | `:394-417`, `:431-453` (centered `Column` shrinks the button), `:473-503` | **Pinned action bar**: `Scaffold.bottomNavigationBar: SafeArea(Padding(s4, child: _RequestAction))`, every state a full-width 56 pt control (new token `WarmPlayfulSize.actionHeight = 56`) with a one-line status under it in `wp.muted`: idle = primary "Request to join"; sending = same button, spinner + "Sending…"; pending = tonal disabled "Requested" + "Waiting for Dario to reply"; approved = primary "Open chat" (icon `chat_bubble`), success-tinted status "You're matched!"; denied = tonal disabled "Not selected" + "This one didn't work out. Plenty more on Discover."; women-only = disabled + "This meal is for women only."; own = tonal "Your meal" + "Requests arrive in the Requests tab." | M |
| MEAL-02 | P1 | The "Requested" and women-only buttons shrink to the label width; the label touches the button edges. | `shots/iphone17-light-default__42_meal_detail_requested.png`, `shots/iphone17-light-default__46_meal_detail_women_only_disabled.png` | `Column` default `crossAxisAlignment.center` (`:431`, `:543`) shrinks the button to its child; and each site's `FilledButton.styleFrom(padding: EdgeInsets.symmetric(vertical: s4))` sets horizontal padding to 0, which is why the label touches the edges (true of every `FilledButton` with that override) | Closed by MEAL-01 (`crossAxisAlignment: stretch`) and X-02 (remove per-site padding overrides) | (MEAL-01) |
| MEAL-03 | P1 | "Matched!" is an off-palette bright teal block (seed `tertiaryContainer`), identical in dark mode where it glares. | `shots/iphone17-light-default__43_meal_detail_matched.png`, `shots/iphone17-dark-default__43_meal_detail_matched.png` | `:474` `colors.tertiaryContainer` (not overridden in `theme.dart`) | Map `tertiaryContainer`/`onTertiaryContainer` to `wp.sage` / text in `theme.dart`; closed by MEAL-01 | S |
| MEAL-04 | P2 | A rejected join request (meal no longer open) **may** show no error. Mechanism real, behaviour unverified: the error listener lives in `_RequestToJoinButton`, which the optimistic "Requested" state unmounts; but `CreateRequestController` is keepAlive and the button re-subscribes when it comes back, so the snackbar may still fire. Shot 49 was taken ~6 s after the tap, after a 4 s snackbar would have gone, so it can neither confirm nor refute. Verify with an early capture or a widget test before treating it as a bug. | `shots/iphone17-light-default__49_meal_detail_request_rejected.png` (inconclusive) | `meal_detail_screen.dart:377-389` | If confirmed: move the `ref.listen` to `_RequestAction` (always mounted) and show "This meal is no longer open." | S |
| MEAL-05 | P1 | Large text, small phone: the restaurant name breaks one syllable per line next to the "Women only" badge. | `shots/se3-light-xxl__46_meal_detail_women_only_disabled.png` | `Row(Expanded(name), badge)` (`:79-95`) with the badge unconstrained | Put the badge on its own line below the name (`Wrap`) | S |
| MEAL-06 | P2 | Address and host bio unreadable (X-01); "Your meal" pill unreadable. | `shots/iphone17-light-default__40_meal_detail_open.png`, `shots/iphone17-light-default__48_meal_detail_own.png` | `:100`, `:276`, `:594` | X-01 | (X-01) |
| MEAL-07 | P2 | Not selected / requested give no next step. | `shots/iphone17-light-default__44_meal_detail_not_selected.png` | — | Status copy in MEAL-01 | (MEAL-01) |
| MEAL-08 | P2 | On your own meal the menu still offers "Report" (of your own meal). | `shots/iphone17-light-default__48_meal_detail_own.png` | `_MealSafetyActions` `isHost ? 'Report'` (`:161`) | Hide the safety menu when `isHost` | S |
| MEAL-09 | P2 | Logged but not visible in any captured viewport: `UXOVERFLOW … 195 px (222 on SE) on the right` at xxl for 40/44/45/46/49 and 23-25. No stripe appears in the visible part of those screens. The likeliest source is Discover's `_HostInfo` row, which has no `Expanded`/`Flexible` around the host name and stays laid out under the pushed detail route ("Emilia Vasquez-Hernandez" at xxl is wider than the card). Unconfirmed, so P2. | `shots/iphone17-light-xxl__24_discover_notice_dismissed.png` (row is laid out; the long-name card is off screen) | `discovery_screen.dart:303-322` | Wrap the name in `Flexible`, `maxLines: 1, overflow: ellipsis`; confirm with a widget test at `TextScaler.linear(2.0)` and 320 px | S |

### 9. Requests inbox (`lib/features/matching/presentation/request_inbox_screen.dart`, `widgets/request_inbox_tile.dart`)

**Works:** guest name + age, which meal and when (readable: it uses `onSurface`), "Meal time has passed" chip with Approve disabled and a semantics hint, outcome snackbar with a Chat action and a timeout.

| ID | Sev | Finding | Evidence | Cause | Fix | Effort |
|---|---|---|---|---|---|---|
| REQ-01 | P1 | **Approve looks like plain text** (its fill equals the tile, 1.00:1) while Deny is an outlined coral button: the destructive action is the most prominent one. | `shots/iphone17-light-default__52_requests_data.png`, `shots/iphone17-dark-default__52_requests_data.png` | `FilledButton` on a `surfaceContainerHighest` (= surface) tile (`:130-150`) | X-02: Approve = primary filled; Deny = `TextButton` in `dangerText` (or outlined neutral) | (X-02) |
| REQ-02 | P1 | Approve/Deny in flight: no spinner, **every** tile's buttons go disabled at once (one shared controller). | `shots/iphone17-light-default__54_requests_approve_in_flight.png` | `inboxActionControllerProvider` is global; `isSubmitting` read by every tile (`:118`) | Track the pending request id in the controller state; spinner only in the pressed button of that tile | M |
| REQ-03 | P1 | Small phone + large text: the button row overflows 16 px and clips "Approve". | `shots/se3-light-xxl__52_requests_data.png` | `Row(mainAxisAlignment: end)` (`:239-260`) | `OverflowBar(alignment: end, overflowAlignment: end)` so buttons stack when they do not fit | S |
| REQ-04 | P2 | The host decides on name + age only: no rating, no bio, no photo enlargement, although `RatingBadge` exists and the guest doc is already watched. | `shots/iphone17-light-default__52_requests_data.png` | `:109-116` | Add `RatingBadge(uid: guestId)` under the name (existing widget, no new data) | S |
| REQ-05 | P2 | The Requests tab icon `mark_email_unread` has a built-in "unread" dot, so the tab always looks like it has news, even with 0 pending or errored. | `shots/iphone17-light-default__61_chats_empty.png` (tab bar, nothing pending yet), `shots/iphone17-light-default__91_requests_error.png` | `app_shell.dart:43-48` | Use `Icons.inbox_outlined` / `Icons.inbox` with the existing `Badge` | S |
| REQ-06 | P2 | "Meal time has passed" chip is a saturated seed red in dark mode (off-palette). | `shots/iphone17-dark-default__52_requests_data.png` | `colors.errorContainer` (`:213`) from the seed | Map `errorContainer` to a palette tint in `theme.dart` (X-08) | S |

### 10. Chats list (`lib/features/chat/presentation/chat_list_screen.dart`, `widgets/chat_list_tile.dart`)

**Works:** avatar, name, one-line preview, relative time, unread dot.

| ID | Sev | Finding | Evidence | Cause | Fix | Effort |
|---|---|---|---|---|---|---|
| CHATS-01 | P2 | Preview and time unreadable (X-01); no meal context (which restaurant / when) in the row. | `shots/iphone17-light-default__62_chats_data.png` | `chat_list_tile.dart:106`, `:120` | `wp.muted`; second line "Pizzeria Popolare · Tue 20:30" (data from `matchMealProvider`, already used by the post-meal card) | S |
| CHATS-02 | P2 | Empty state is one faint line, no action. Loading is a tiny spinner. | `shots/iphone17-light-default__61_chats_empty.png`, `shots/iphone17-light-default__60_chats_loading.png` | `chat_list_screen.dart:30`, `:40-51` | `EmptyState` with "Find a meal" → Discover; skeleton rows (X-06) | S |

### 11. Chat (`lib/features/chat/presentation/chat_screen.dart`, `widgets/{message_bubble,message_composer}.dart`, `safety/presentation/widgets/safety_tips_card.dart`)

**Works:** partner name, photo and rating in the app bar; clear mine/theirs bubbles; "Seen" on my last message; send spinner in the send button (`shots/iphone17-light-default__66_chat_send_pending.png`); report/block menu.

| ID | Sev | Finding | Evidence | Cause | Fix | Effort |
|---|---|---|---|---|---|---|
| CHAT-01 | **P0** | At large text the "Stay safe" card fills the screen: **no message is visible and the composer is pushed off screen** (overflow 55 px on SE); with the keyboard open on iPhone 17 the composer and every message are hidden (overflow 225 px). Chat is unusable at xxl. | `shots/se3-light-xxl__63_chat_messages.png`, `shots/iphone17-light-xxl__66_chat_send_pending.png`, `shots/iphone17-light-xxl__72_chat_post_meal_card.png` | Two fixed cards above an `Expanded` list in a non-scrolling `Column` (`chat_screen.dart:138-211`) | Remove both cards from the fixed column: safety tips become a one-line tappable banner ("Meeting up? Safety tips") opening a sheet, dismissible per chat; the post-meal prompt becomes the first item of the reversed list (scrolls) | M |
| CHAT-02 | P1 | **(Owner)** At default size the safety card takes ~25% of the screen (~35% on SE) and cuts the first visible message in half. | `shots/iphone17-light-default__63_chat_messages.png`, `shots/se3-light-default__63_chat_messages.png` | same | Closed by CHAT-01 | (CHAT-01) |
| CHAT-03 | P1 | The chat never says which meal it is about (restaurant, date, address). For a meal-first app this is the one fact both people need. | `shots/iphone17-light-default__63_chat_messages.png` | — | Compact pinned header under the app bar: "Pizzeria Popolare · Tue 6 Oct, 20:30" → tap opens meal detail (data: `matchMealProvider`) | S |
| CHAT-04 | P1 | Timestamps and "Seen" unreadable (X-01). | `shots/iphone17-light-default__63_chat_messages.png`, `shots/iphone17-dark-default__63_chat_messages.png` | `message_bubble.dart:61`, `:66` | X-01 | (X-01) |
| CHAT-05 | P2 | A timestamp under every bubble, no day separators: "10:00 AM" is followed by "6:50 AM" (next day) with nothing in between. | `shots/iphone17-light-default__63_chat_messages.png` | `message_bubble.dart:58-62` | Group by day with a centered day label ("Today", "Mon 5 Oct"); show time only on the last bubble of a 5-minute run | M |
| CHAT-06 | P2 | While sending, the text stays in the field *and* the optimistic bubble shows it: looks duplicated. | `shots/iphone17-light-default__66_chat_send_pending.png` | `message_composer.dart:30-41` clears after the await | Clear immediately, restore the text on failure | S |
| CHAT-07 | P2 | Messages failed to load: the composer stays active under the error. | `shots/iphone17-light-default__90_chat_error.png` | `chat_screen.dart:161-168` | `ErrorState` with Retry (X-07) | (X-07) |

### 12. Report sheet + block (`lib/features/safety/presentation/report_sheet.dart`, `widgets/safety_actions.dart`)

**Works:** five reason chips, optional note, confirm before block, thank-you snackbar.

| ID | Sev | Finding | Evidence | Cause | Fix | Effort |
|---|---|---|---|---|---|---|
| REPORT-01 | **P0** | With the note focused, **Submit is under the keyboard** on SE at default text (overflow 83 px) and at xxl on iPhone 17 (210 px); the multiline field's return key inserts a newline, so the keyboard cannot be dismissed. A safety report cannot be sent. (Capture: `UXMISSING 70` on se3-default and both xxl cells.) | `shots/se3-light-default__69_chat_report_filled.png`, `shots/iphone17-light-xxl__69_chat_report_filled.png` | `Column(mainAxisSize: min)` with `viewInsets` padding but no scroll (`report_sheet.dart:106-178`) | `SingleChildScrollView` inside the sheet; `DraggableScrollableSheet` not needed. Submit stays reachable; `textInputAction: done` on the note | S |
| REPORT-02 | P1 | Enabled Submit has no visible fill (sheet surface = button fill): it reads as a text label. Note field has no visible boundary until focused (input fill = sheet surface). | `shots/iphone17-light-default__69_chat_report_filled.png`, `shots/iphone17-light-default__68_chat_report_sheet.png` | `filledButtonTheme`, `inputDecorationTheme.fillColor: surface` (`theme.dart:217`) | X-02; inputs inside sheets get `bg` fill or a 1 px `wp.muted` enabled border | S |
| REPORT-03 | P2 | Title "Report" does not say who/what is reported; selected chip label is cream on coral (2.18 light, **1.91 dark**). | `shots/iphone17-dark-default__69_chat_report_filled.png` | `:118-124`; `chipTheme.secondaryLabelStyle` cream (`theme.dart:241-242`) | "Report Bastien" / "Report this meal"; X-08 for the chip | S |
| REPORT-04 | P2 | Block confirm: "Block" is styled like Cancel (Delete account uses the danger colour) and does not name the person. | `shots/iphone17-light-default__71_chat_block_dialog.png` | `safety_actions.dart:82-86` | "Block Bastien?"; confirm in `dangerText` | S |

### 13. Rating sheet + post-meal card (`lib/features/rating/presentation/rating_sheet.dart`, `widgets/post_meal_card.dart`)

**Works:** prompt appears only after the meal, stars + "did they show up?" + optional comment, thank-you snackbar.

| ID | Sev | Finding | Evidence | Cause | Fix | Effort |
|---|---|---|---|---|---|---|
| RATE-01 | P1 | With the comment focused on SE (default text), Submit is squeezed under an overflow stripe at the keyboard edge (`UXMISSING 75`: the tap missed). The comment is optional, so typing nothing still works. | `shots/se3-light-default__74_rating_sheet_filled.png` | same pattern as REPORT-01 (`rating_sheet.dart:88-176`) | Same fix as REPORT-01 | S |
| RATE-02 | P1 | Post-meal card + safety card together take ~40% of the chat; the "Rate" button has no visible fill (card surface = button fill). | `shots/iphone17-light-default__72_chat_post_meal_card.png` | `post_meal_card.dart:68-114`; X-02 | CHAT-01 (card scrolls with the list) + X-02 | (CHAT-01, X-02) |
| RATE-03 | P2 | Unselected stars are sage outlines at 2.05:1 on the sheet (UI needs 3:1); the sheet repeats the card's question and does not name the person. | `shots/iphone17-light-default__73_rating_sheet.png` | `rating_sheet.dart:117-123` uses `colors.tertiary` | Unselected `wp.muted` outline, selected `wp.butter`-dark/`tertiary` fill; title "How was your meal with Giulia?" | S |
| RATE-04 | P2 | Large text: the post-meal card alone overflows 233 px with the safety card. | `shots/iphone17-light-xxl__72_chat_post_meal_card.png` | — | CHAT-01 | (CHAT-01) |

### 14. Profile edit (`lib/features/user/presentation/profile_edit_screen.dart`)

**Works:** same form as setup, own rating shown, photos editable.

| ID | Sev | Finding | Evidence | Cause | Fix | Effort |
|---|---|---|---|---|---|---|
| PROF-01 | P1 | Saving (or adding/removing a photo) writes `users/{uid}`, which rebuilds the router and resets the navigation stack to Discover (README "App behaviours found"); the user is thrown out of their own tab. | README; `shots/iphone17-light-default__15_profile_setup_filled.png` → `__16_profile_setup_ready.png` shows the same reset on setup | `router.dart:116-120` | X-09 | (X-09) |
| PROF-02 | P1 | Save has no visible fill and is always enabled, even with no change; no "Saved" confirmation (it pops, but this screen is a tab root, so pop does nothing useful). | `shots/iphone17-light-default__80_profile_edit.png` | `profile_edit_screen.dart:49-53` `Navigator.pop` on a tab root | Enable Save only when dirty; on success show a snackbar "Profile saved" and stay | S |
| PROF-03 | P2 | The tab is called Profile but opens a form titled "Edit profile"; the rating floats unlabelled at the top; Settings hides behind a gear. | `shots/iphone17-light-default__80_profile_edit.png` | `:66-87` | Title "Profile"; label "Your rating ★ 4.7 (7)"; keep the gear but add a "Settings" row at the bottom (SET-04) | S |
| PROF-04 | P2 | Large text, keyboard: same keyboard-cover pattern as setup. | `shots/iphone17-light-xxl__14_profile_setup_empty.png` | — | `scrollPadding` | S |

### 15. Settings (`lib/features/settings/presentation/settings_screen.dart`)

**Works:** grouped list, destructive item in danger colour with a confirm dialog that says it is permanent (`shots/iphone17-light-default__85_settings_delete_dialog.png`), version shown, spinner while deleting.

| ID | Sev | Finding | Evidence | Cause | Fix | Effort |
|---|---|---|---|---|---|---|
| SET-01 | P1 | "Delete account" text is danger on bg, **2.84:1**. | `shots/iphone17-light-default__83_settings.png` | `:150-154` | `dangerText` (X-04) | (X-04) |
| SET-02 | P2 | Section headers unreadable (X-01); order puts Legal first and Account second. | `shots/iphone17-light-default__83_settings.png`, `shots/iphone17-dark-default__83_settings.png` | `:209` | SET-04 order | S |
| SET-03 | P2 | Sign out has no confirm and no progress (it awaits the push-token unregister first). | `shots/iphone17-light-default__83_settings.png` | `:92-110` | Confirm dialog; row spinner while running | S |
| SET-04 | — | **Owner ask 4: proposed structure.** See the table after this one. | — | — | — | — |

**SET-04: proposed Settings structure (owner ask 4).** Default verdict on anything new is CUT (`docs/PRINCIPLES.md`). Status: **E** exists in app today · **B** backend/feature exists, needs UI only · **N** new scope, owner decision.

| Group | Item | Status | Size | Justification |
|---|---|---|---|---|
| Account | Edit profile (row → `/profile`) | E (screen exists; reached only via tab) | S | Discoverability; Settings is where people look |
| Account | Phone number (read-only, shows the signed-in number) | B (`FirebaseAuth.currentUser.phoneNumber`, read via the auth repository) | S | Reassurance, support; read-only keeps it in scope |
| Account | Change phone number | N | M | Needs re-verification flow; CUT for v1 |
| Account | Sign out (with confirm) | E | S | Moved from Discover (DISC-04) |
| Account | Delete account | E | — | Already correct (store requirement) |
| Safety | Blocked people (list + Unblock) | B: `BlockRepository` already has `watchBlockedUserIds` and `unblock` (`safety/domain/repositories/block_repository.dart:4,8`), and `firestore.rules:285` already lets the blocker delete their block. Only a screen is missing | M | Today a block is permanent and invisible; an undo path is basic safety hygiene for a UGC app. No backend or rules change |
| Safety | Safety tips (static page) | E (content exists in `SafetyTipsCard`) | S | Gives the tips a home once they leave the chat (CHAT-01) |
| Safety | Report a problem / Contact us (`mailto:`) | N, but trivial (no backend) | S | Store review expects a support contact; recommend IN |
| Notifications | Push on/off per type | N (only OS-level permission exists) | M-L | CUT: iOS Settings already gives an on/off; per-type toggles need backend filtering |
| Notifications | "Open iOS notification settings" row | N, trivial (`app_settings`-style deep link or `openAppSettings`) | S | Cheap, optional |
| Legal | Privacy Policy, Terms | E | — | Keep |
| Legal | Open-source licences (`showLicensePage`) | N, trivial (Flutter built-in) | S | Required in spirit for OFL font + packages; recommend IN |
| About | Version | E | — | Keep |
| About | Language | N | L | Depends on the localisation decision (X-13) |

Recommended for Part B without new backend (all S except Blocked people, M): Edit profile row, phone (read-only), Sign out confirm, Blocked people, Safety tips page, Contact (mailto), Licences. **Owner decisions:** notification controls, change phone, language, and whether "Contact us" gets a real support address.

Proposed order:

```
Settings
  Account        Edit profile · Phone (+33 6 •• •• 56 78, read-only) · Sign out
  Safety         Blocked people · Safety tips · Contact us
  Notifications  (owner decision; if CUT, one row "Notification settings" → iOS Settings)
  Legal          Privacy Policy · Terms of Service · Licences
  About          Version
  ─────────────
  Delete account (danger, last, separated)
```

Widgets: `ListView` of `ListTile`s (existing), section headers as `ListTile`-aligned `Text` in `textTheme.labelLarge` + `wp.muted`, chevron `Icons.chevron_right_rounded` on navigating rows, `ListTile.subtitle` for the phone. No new primitives.

### 16. Error states 90-93 (all feeds)

| ID | Sev | Finding | Evidence | Cause | Fix | Effort |
|---|---|---|---|---|---|---|
| ERR-01 | P1 | Every feed failure renders the same bare sentence in danger colour (2.84:1) with **no retry**, no icon, no explanation; Discover keeps the Paris notice above it; chat keeps an active composer. Pull-to-refresh works on Discover and Requests but nothing says so. | `shots/iphone17-light-default__90_chat_error.png`, `__91_requests_error.png`, `__92_chats_error.png`, `__93_discover_error.png` | `discovery_screen.dart:124-127`, `request_inbox_screen.dart:49-52`, `chat_list_screen.dart:31-37`, `chat_screen.dart:161-168` | X-07 `ErrorState` | (X-07) |

---

## (c) Cross-cutting findings

### X-01 (P0) Secondary text drawn in the border colour: contrast

Measured (`docs/ux/contrast-measured.txt`): border-as-text **1.22:1 on bg / 1.15:1 on surface** (light), **1.36 / 1.22** (dark). Requirement 4.5:1.

**Full list of `colorScheme.outline` uses in `lib/` (36):**

Text colour (27, all fail):

| # | file:line | What |
|---|---|---|
| 1 | `features/auth/presentation/signin_screen.dart:146` | "Sign in to get started." |
| 2 | `features/auth/presentation/signin_screen.dart:173` | "or" |
| 3 | `features/auth/presentation/phone_verify_screen.dart:94` | "We texted you a 6-digit code." |
| 4 | `features/onboarding/presentation/age_gate_screen.dart:159` | "You must be 18 or older…" |
| 5 | `features/onboarding/presentation/profile_setup_screen.dart:86` | setup subtitle |
| 6 | `features/meal/presentation/discovery_screen.dart:129` | empty "No meals near you yet" |
| 7 | `features/meal/presentation/discovery_screen.dart:231` | card date/time |
| 8 | `features/meal/presentation/discovery_screen.dart:236` | card distance |
| 9 | `features/meal/presentation/restaurant_search_screen.dart:90` | "No matches" |
| 10 | `features/meal/presentation/restaurant_search_screen.dart:179` | row address |
| 11 | `features/meal/presentation/create_meal_screen.dart:173` | restaurant address |
| 12 | `features/meal/presentation/meal_detail_screen.dart:100` | restaurant address |
| 13 | `features/meal/presentation/meal_detail_screen.dart:233` | "Host unavailable" |
| 14 | `features/meal/presentation/meal_detail_screen.dart:276` | host bio |
| 15 | `features/meal/presentation/meal_detail_screen.dart:450` | "Waiting for the host" |
| 16 | `features/meal/presentation/meal_detail_screen.dart:563` | "This meal is women-only." |
| 17 | `features/meal/presentation/meal_detail_screen.dart:594` | "Your meal" |
| 18 | `features/matching/presentation/request_inbox_screen.dart:56` | "No pending requests" |
| 19 | `features/chat/presentation/chat_list_screen.dart:47` | empty chats copy |
| 20 | `features/chat/presentation/widgets/chat_list_tile.dart:106` | last-message preview |
| 21 | `features/chat/presentation/widgets/chat_list_tile.dart:120` | relative time |
| 22 | `features/chat/presentation/chat_screen.dart:175` | "Say hi 👋" |
| 23 | `features/chat/presentation/widgets/message_bubble.dart:61` | message time |
| 24 | `features/chat/presentation/widgets/message_bubble.dart:66` | "Seen" |
| 25 | `features/rating/presentation/widgets/rating_badge.dart:39` | "New" |
| 26 | `features/rating/presentation/widgets/post_meal_card.dart:95` | "Rate Giulia" |
| 27 | `features/settings/presentation/settings_screen.dart:209` | section headers |

Icon colour on meaningful icons (8; non-text needs 3:1, all at 1.15-1.22):

| # | file:line | What |
|---|---|---|
| 28 | `features/meal/presentation/discovery_screen.dart:313` | host avatar placeholder |
| 29 | `features/meal/presentation/meal_detail_screen.dart:253` | host avatar placeholder |
| 30 | `features/matching/presentation/widgets/request_inbox_tile.dart:169` | guest avatar placeholder |
| 31 | `features/chat/presentation/widgets/chat_list_tile.dart:85` | avatar placeholder |
| 32 | `features/chat/presentation/chat_screen.dart:241` | app-bar avatar placeholder |
| 33 | `features/user/presentation/widgets/profile_form.dart:328` | broken-image icon |
| 34 | `features/user/presentation/widgets/profile_form.dart:384` | **add-photo icon (an enabled control)** |
| 35 | `features/chat/presentation/widgets/message_composer.dart:115` | send icon when disabled (exempt as disabled, but should match the theme's disabled colour) |

Decorative (1): `features/safety/presentation/widgets/safety_tips_card.dart:91` bullet dot (fine as border colour, but `wp.muted` reads better).

Explicit border uses of `colorScheme.outline` in feature code: **0**. Implicit border uses: **3** unthemed `OutlinedButton`s, whose M3 default side is `colorScheme.outline` (and whose default label is coral, SIGNIN-01): `signin_screen.dart:273` (Google/Apple), `create_meal_screen.dart:180` (Pick date & time), `age_gate_screen.dart:162` (Select date of birth). That is the intended role of `outline`, but at 1.15-1.22:1 the button boundary fails the 3:1 UI-component requirement (the label carries the meaning, so P2); the `outlinedButtonTheme` in B1-2 should give them a `wp.muted` side. (The theme itself uses the `border` token directly for chip sides and the drag handle.)

**Fix (B1-1):** `colors.outline` → `wp.muted` (text and meaningful icons), new light `muted #7A6352`; `colorScheme.onSurfaceVariant = muted` so Material defaults (ListTile subtitles, hints, helper text) follow; a test that fails on `colorScheme.outline` used as a `TextStyle.color` or `Icon.color` under `lib/features/` (grep test, S). Do **not** use `wp.subtle` for text: 2.25-2.40:1 light.

### X-02 (P1) Primary buttons are drawn as surfaces (same-surface `FilledButton`)

`filledButtonTheme` paints `FilledButton` with `surface` and `onSurface` (`theme.dart:186-199`). DESIGN.md calls `FilledButton` the *secondary* button, but every primary action in the app is a `FilledButton`; `ElevatedButton` (the documented primary) is not used. Result: fill vs bg ~1.07:1, fill vs card/sheet surface **1.00:1**, and disabled (grey) buttons look stronger than enabled ones.

All 14 `FilledButton`s:

| file:line | Action | Sits on |
|---|---|---|
| `auth/presentation/signin_screen.dart:267` | Send code | bg |
| `auth/presentation/phone_verify_screen.dart:122` | Verify | bg |
| `onboarding/presentation/age_gate_screen.dart:187` | Continue | bg |
| `onboarding/presentation/profile_setup_screen.dart:91` | Continue | bg |
| `user/presentation/profile_edit_screen.dart:89` | Save | bg |
| `meal/presentation/create_meal_screen.dart:243` | Create meal | bg |
| `meal/presentation/meal_detail_screen.dart:394` | Request to join | bg |
| `meal/presentation/meal_detail_screen.dart:433` | Requested (disabled) | bg |
| `meal/presentation/meal_detail_screen.dart:517` | Not selected (disabled) | bg |
| `meal/presentation/meal_detail_screen.dart:545` | Request to join (women-only, disabled) | bg |
| `matching/presentation/widgets/request_inbox_tile.dart:130` | Approve | **surface tile (1.00:1)** |
| `safety/presentation/report_sheet.dart:155` | Submit | **surface sheet (1.00:1)** |
| `rating/presentation/rating_sheet.dart:152` | Submit | **surface sheet (1.00:1)** |
| `rating/presentation/widgets/post_meal_card.dart:102` | Rate | **surface card (1.00:1)** |

**Fix (B1-2), design-system decision (mine, recorded in DESIGN.md):** follow Material 3 semantics: `FilledButton` = primary: fill `primary` (coral), label `onPrimary`; `FilledButton.tonal` / `OutlinedButton` = secondary; `TextButton` = ghost. Set `onPrimary` (and the chip `secondaryLabelStyle`, FAB, date picker) to **brown `#3D2E1F` in both modes**: 5.77:1 on light coral, 6.58:1 on dark coral (hand-computed); today's cream is 2.18 / 1.91. Coral fill vs light bg stays 2.18:1: acceptable because the 5.77:1 label identifies the control, and changing the brand coral is out of scope. If the owner wants the *fill* itself ≥3:1 on cream, the token would be a terracotta `accentStrong #B84A36` with cream label (4.97:1 label, 4.97:1 fill vs bg, hand-computed): a visible brand shift, **owner decision**. Height: `minimumSize` 48 stays, primary page CTAs use 56 (`WarmPlayfulSize.actionHeight`, new token). All call sites drop their per-site `styleFrom(padding, shape: radius sm)`: buttons use radius `md` (16) per DESIGN.md, currently overridden to `sm` (12) at 13 sites.

### X-03 (P1) In-flight spinners are invisible

Nine button spinners are coloured `colors.onPrimary` (cream) and drawn while the button is disabled (grey fill): `signin_screen.dart:250`, `phone_verify_screen.dart:136`, `age_gate_screen.dart:201`, `profile_setup_screen.dart:107`, `profile_edit_screen.dart:103`, `create_meal_screen.dart:258`, `meal_detail_screen.dart:411`, `report_sheet.dart:170`, `rating_sheet.dart:167`. (Line numbers point at the `CircularProgressIndicator(`; the `color:` line is +2.) Cream on the disabled fill measures **1.24-1.32:1** (verifier, from the PNGs). Visible result: a 2 px tick (`shots/iphone17-light-default__05_phone_verify_in_flight.png`, `__37_create_meal_in_flight.png`, `__70_chat_report_in_flight.png`, `__75_rating_sheet_in_flight.png`). The shots are frozen frames (emulator paused), so the arc is captured mid-rotation; a live spinner is easier to notice than a still, but at that contrast it is still effectively invisible. **4 of the 9** (age gate, profile setup, profile save, request to join) are never on screen in practice, because the write is optimistic and the UI moves on first. **Fix:** one `AppButton({variant, label, onPressed, isLoading})` in `lib/core/design/widgets/` (new folder, shared): while loading it keeps its enabled colours, ignores taps (`onPressed: isLoading ? () {} : …` with `AbsorbPointer`), shows a 20 px spinner in the **foreground** colour beside the label ("Sending…"), and announces via `Semantics(liveRegion: true)`. Size never changes.

### X-04 (P1) Danger colour as text

`danger #E07A5F` is 2.84:1 on bg, 2.67:1 on surface (light). Used as text for every error message (`colors.error`: 13 sites, e.g. `signin_screen.dart:208`, `discovery_screen.dart:126`, `settings_screen.dart:153`). **Fix:** new token `dangerText` light `#A84A35` (5.47:1 bg, 5.13:1 surface, hand-computed), dark keeps `#F09781` (7.0:1); `colorScheme.error` = `dangerText` for text; `danger` stays for icons/fills. Other consumers of `colorScheme.error` to review when B1-4 changes it: the Deny button foreground and border (`request_inbox_tile.dart:246-247`), the "Delete account" dialog confirm (`settings_screen.dart:58`), the settings delete icon and its spinner (`settings_screen.dart:150`, `:161`), and the age-gate blocked icon (`age_gate_screen.dart:118`). All of these get darker, which is fine (≥3:1 either way). Material's own uses follow too (field error borders/text, `Badge` background in the tab bar): check the Requests badge still reads as the brand terracotta. Evidence: `shots/iphone17-light-default__93_discover_error.png`, `shots/iphone17-light-default__83_settings.png`.

### X-05 (P1) Font: Nunito applies to 4 of 15 text styles, and is downloaded at runtime

`theme.dart:80-147` builds `GoogleFonts.nunitoTextTheme(...)` then `copyWith` replaces 11 slots with plain `TextStyle`s that have no `fontFamily`, so they fall back to the iOS system font (SF Pro). Only `displaySmall`, `headlineSmall`, `titleSmall`, `labelSmall` keep Nunito; the app uses `headlineSmall` (the four onboarding titles). Reconciling with `ux_audit/README.md:209` ("two text styles"): the README undercounts; 4 theme slots keep Nunito and 1 of them is used in `lib/features/`. The audit's figure is the correct one; the README is left unchanged in this task. Visible in every shot: "Welcome to Convyve" is Nunito, everything else (buttons, body, app-bar titles) is SF (`shots/iphone17-light-default__01_signin.png`). DESIGN.md's "type carries weight: Nunito 700/800" is not delivered.

`google_fonts` fetches the font from `fonts.gstatic.com` at first use: a flash of system font on first launch, system font offline, and a request to Google carrying the user's IP before any consent: a **GDPR exposure for an EU launch** (German courts have fined websites for exactly this with Google Fonts). **Recommend:** bundle Nunito (OFL) as assets (`assets/fonts/Nunito-{Medium,Bold,ExtraBold}.ttf` + `OFL.txt`), declare in `pubspec.yaml` `fonts:`, set `ThemeData(fontFamily: 'Nunito')` and give every `TextStyle` in `theme.dart` `fontFamily: WarmPlayfulFonts.body`, remove `google_fonts` (or set `GoogleFonts.config.allowRuntimeFetching = false`). Add the font to the licence page (SET-04). Effort S; app size +~250 kB.

### X-06 (P1) Loading and progress: inventory and one pattern (owner ask 3)

| # | Async action / load | Where | Indicator today | Seen in capture |
|---|---|---|---|---|
| 1 | Google sign-in | `signin_screen.dart:55` | button spinner (coral on outline) | not capturable (native) |
| 2 | Apple sign-in | `:74` | button spinner | not capturable |
| 3 | Send code | `:91` | spinner **gone before the code arrives** | `__03_signin_phone_waiting` (none) |
| 4 | Verify code | `phone_verify_screen.dart:44` | invisible spinner | `__05_phone_verify_in_flight` |
| 5 | Age gate Continue | `age_gate_screen.dart:197` | invisible spinner; optimistic, never on screen | not capturable |
| 6 | Photo upload | `profile_form.dart:375` | spinner in the add tile (coral) | not capturable (native picker) |
| 7 | Profile setup Continue | `profile_setup_screen.dart:103` | invisible spinner; optimistic | not capturable |
| 8 | Profile Save | `profile_edit_screen.dart:99` | invisible spinner; router reset | not capturable |
| 9 | Discover feed | `discovery_screen.dart:123` | centered spinner | `__20_discover_loading` |
| 10 | Discover refresh | `:44` | pull-to-refresh | `__25_discover_refreshing` (works) |
| 11 | Restaurant search | `restaurant_search_screen.dart:75` | centered spinner | not capturable |
| 12 | Create meal | `create_meal_screen.dart:254` | invisible spinner | `__37_create_meal_in_flight` |
| 13 | Meal detail: host | `meal_detail_screen.dart:220` | centered spinner | not captured |
| 14 | Meal detail: request state | `:321` | centered spinner | not captured |
| 15 | Request to join | `:407` | spinner never rendered (optimistic) | `__40` → `__42` |
| 16 | Request rejected by server | `:377` | snackbar in code; may not fire (mechanism real, behaviour unverified, MEAL-04) | `__49_meal_detail_request_rejected` (inconclusive: taken ~6 s after the tap) |
| 17 | Requests inbox | `request_inbox_screen.dart:48` | centered spinner | not capturable (preloaded by the badge) |
| 18 | Approve / Deny | `request_inbox_tile.dart:118` | **none**, all tiles disabled | `__54`, `__55` |
| 19 | Chats list | `chat_list_screen.dart:30` | centered spinner | `__60_chats_loading` |
| 20 | Chat messages | `chat_screen.dart:160` | centered spinner | not captured |
| 21 | Send message | `message_composer.dart:104` | spinner in send button | `__66_chat_send_pending` (works) |
| 22 | Report submit | `report_sheet.dart:166` | invisible spinner | `__70_chat_report_in_flight` |
| 23 | Rating submit | `rating_sheet.dart:163` | invisible spinner | `__75_rating_sheet_in_flight` |
| 24 | Block | `safety_actions.dart:101` | **none** | dialog only, `__71` |
| 25 | Delete account | `settings_screen.dart:155` | row spinner | not captured (cancelled) |
| 26 | Sign out (both entry points) | `settings_screen.dart:92`, `discovery_screen.dart:61` | **none** (awaits token unregister) | not captured |
| 27 | Row data: host name, guest, rating badge, avatars | `_HostInfo`, `RatingBadge`, `CircleAvatar(NetworkImage)` | placeholder text "Host"/"Chat"/"Guest", badge collapses to nothing, avatars pop in | `__22`, `__62` |

Tally (27): working 13 (#1, 2, 6, 9, 10, 11, 13, 14, 17, 19, 20, 21, 25; only #9, 10, 19, 21 were captured, the rest exist in code), invisible / ends early / never rendered 9 (#3, 4, 5, 7, 8, 12, 15, 22, 23), none 4 (#18, 24, 26, 27), unverified 1 (#16).

**One pattern (B1-4 + per-screen):**
- **Lists and feeds** (Discover, Requests, Chats, chat messages, search results): 3 skeleton rows shaped like the real card (`SkeletonCard` in `lib/core/design/widgets/`, `wp.border`-tinted blocks, shimmer with `flutter_animate` (installed) `.shimmer(duration: 1200ms)`, static when `MediaQuery.disableAnimations`).
- **Buttons**: the pressed button only shows a spinner in its own label colour, same size (X-03). Row actions (Approve/Deny) are per-row (REQ-02).
- **Optimistic writes** (request, age gate, setup, save): no spinner needed, but every rejection must surface (MEAL-04 pattern: listen where the widget stays mounted).
- **Refresh**: pull-to-refresh where a refresh does something (Discover: location + query). Requests and Chats are live streams: their refresh affordance is the Retry in the error state (X-07), not a pull.
- **Rows**: placeholder initials avatar (`CircleAvatar` with initials in `wp.muted`) and `FadeInImage`; keep the rating badge's height while loading (fixed-height `SizedBox`) to avoid layout jumps.
- **Long actions** (sign out, block, delete): row/button spinner; never a full-screen modal.

### X-07 (P1) Error states: one widget with a retry

All feed errors are the same bare red sentence (ERR-01). **Fix:** `ErrorState({message, onRetry})` in `lib/core/design/widgets/`: icon (`Icons.cloud_off_rounded`, `wp.muted`), title "Couldn't load this" (titleMedium), body "Check your connection and try again." (`wp.muted`), `FilledButton.tonal('Try again')` → `ref.invalidate(provider)`. Use in Discover, Requests, Chats, Chat, meal-detail host block, restaurant search. Meal detail's request state already has a Retry (`meal_detail_screen.dart:330-334`): the model to copy. There is **no offline state** anywhere: with `ErrorState` copy mentioning the connection, a dedicated offline banner is P2 and can wait (CUT for v1 unless QA finds it).

### X-08 (P1) Dark-mode parity

| Item | Light | Dark | Evidence |
|---|---|---|---|
| Secondary text (outline) | 1.15-1.22 | 1.22-1.36 | `shots/iphone17-dark-default__22_discover_data.png` |
| Coral text on bg | 2.18 (fail) | 8.75 (pass) | `shots/iphone17-dark-default__01_signin.png` |
| Cream on coral (selected chip, date, switch thumb) | 2.18 | **1.91** | `shots/iphone17-dark-default__69_chat_report_filled.png`, `__11_age_gate_picker.png` |
| Matched banner (seed teal) | off-palette | off-palette, glaring | `shots/iphone17-dark-default__43_meal_detail_matched.png` |
| Past-meal chip (seed red errorContainer) | pink | saturated red | `shots/iphone17-dark-default__52_requests_data.png` |
| Primary buttons (surface fill) | 1.07 vs bg | 1.11 vs bg (hand-computed) | `shots/iphone17-dark-default__40_meal_detail_open.png` |
| Disabled "Requested" label | readable grey | low but readable | `shots/iphone17-dark-default__42_meal_detail_requested.png` |
| Snackbar | default M3 inverse (dark brown) | pale pink block, off-palette | `shots/iphone17-dark-default__26_discover_meal_created.png` |
| Sheets, dialogs, nav bar | ok | ok | `shots/iphone17-dark-default__73_rating_sheet.png`, `__83_settings.png` |

Cause of the off-palette colours: `ColorScheme.fromSeed(...).copyWith(...)` (`theme.dart:47-67`) overrides primary/surface/outline/error/tertiary but leaves `secondaryContainer`, `tertiaryContainer`, `errorContainer`, `primaryContainer`, `inverseSurface` to the seed algorithm, and there is no `snackBarTheme`. The app has no `themeMode` set, so it follows the iOS appearance (correct; no in-app switch is needed). **Fix (B1-3):** map every container role explicitly from palette tokens (peach/sage/butter tints) for both brightnesses. One fix covers both modes: dark parity needs no separate work beyond `onPrimary` (X-02) and the containers.

### X-09 (P1) Any change to the user's own doc resets navigation

`routerProvider` `ref.watch`es `currentUserDocProvider` (`router.dart:118`) and returns a **new** `GoRouter` each time, so any write to `users/{uid}` (photo add/remove, profile save, gender) rebuilds the router at `initialLocation` and remounts the current screen. Evidence: on setup, scroll reset to the top and focus back on Name, with the Name text surviving (`shots/iphone17-light-default__15_profile_setup_filled.png` → `__16_profile_setup_ready.png`). The README ("App behaviours found") also reports the form emptying and the navigation stack resetting to Discover from meal detail; those come from the harness log, not from these shots. **Fix:** build the router once; feed `signedIn/ageVerified/profileComplete` through a `ValueNotifier`/`Listenable` passed as `refreshListenable`, and read the current values inside `redirect`. Only the three redirect booleans should trigger a re-evaluation, never other fields. Effort M (router tests exist: `test/core/routing/redirect_test.dart`).

### X-10 (summary) Large text and keyboard-obscured actions

| Screen | What breaks at `accessibility-extra-large` (or with keyboard) | Evidence | ID |
|---|---|---|---|
| Sign-in | auth labels clipped (overflow 56-107 px right) | `shots/iphone17-light-xxl__01_signin.png` | SIGNIN-02 |
| Phone verify | Verify under keypad, no scroll (P0) | `shots/iphone17-light-xxl__05_phone_verify_in_flight.png` | VERIFY-01 |
| Age gate (SE) | Continue half off screen | `shots/se3-light-xxl__10_age_gate.png` | AGE-03 |
| Discover | notice takes 40% of the viewport; one card per screen | `shots/iphone17-light-xxl__22_discover_data.png` | DISC-02, DISC-07 |
| Meal detail | action below the fold; name broken per letter beside badge (SE) | `shots/iphone17-light-xxl__40_meal_detail_open.png`, `shots/se3-light-xxl__46_meal_detail_women_only_disabled.png` | MEAL-01, MEAL-05 |
| Requests (SE) | Approve clipped | `shots/se3-light-xxl__52_requests_data.png` | REQ-03 |
| Chat | messages and composer unreachable (P0) | `shots/se3-light-xxl__63_chat_messages.png`, `shots/iphone17-light-xxl__66_chat_send_pending.png` | CHAT-01 |
| Report sheet | Submit under keyboard, also SE default (P0) | `shots/iphone17-light-xxl__69_chat_report_filled.png`, `shots/se3-light-default__69_chat_report_filled.png` | REPORT-01 |
| Rating sheet | Submit under keyboard (SE default) | `shots/se3-light-default__74_rating_sheet_filled.png` | RATE-01 |
| Post-meal card | overflow 233 px | `shots/iphone17-light-xxl__72_chat_post_meal_card.png` | CHAT-01 |

Rule for Part B: every screen with a primary action is either scrollable with the action inside, or pins the action in `bottomNavigationBar`/a bottom `SafeArea` that moves with `viewInsets`. Widget tests at `textScaler: TextScaler.linear(2.0)` on a 320×568 surface for each of the screens above.

### X-11 (summary) Tap targets (44 pt)

Measured from code (Flutter logical px = pt):

| Control | Size | Verdict |
|---|---|---|
| Paris notice close (`paris_notice.dart:57-71`) | 24×24 | **fail** (DISC-02) |
| Photo remove "x" (`profile_form.dart:335-346`) | 24×24 | **fail** (SETUP-03) |
| Requests Deny/Approve (theme `minimumSize` 48 high) | ≥48 high | pass |
| Chat send, app-bar icons, rating stars (`IconButton` default 48) | 48 | pass |
| Women-only `Switch`, nav bar, list tiles | ≥48 | pass |
| Add-photo tile | ~105 | pass |

`visualDensity: adaptivePlatformDensity` keeps standard density on iOS, so theme minimums hold.

### X-12 (P2) Type scale, spacing rhythm, copy, dates

- **Type scale.** DESIGN.md defines 6 roles; code uses `bodyMedium.copyWith(fontWeight: h2Weight)` as a de-facto "row title" at 12 sites (restaurant names, host names, "Photos", "I am a", "Women only", "Host") instead of `titleSmall`/`titleMedium`. App-bar titles are `titleLarge` (18). Proposal: add DESIGN.md roles "row title" = `titleSmall` 16/24 w700 and "meta" = `bodySmall` 13/19 w500 `wp.muted`, and use them. P2.
- **Spacing.** Tokens are respected everywhere (no magic numbers found in presentation files). Rhythm issues are density, not tokens: Discover cards spend 4 lines on date + distance; settings rows are 64 pt tall with 24 pt icons. P2.
- **Radius.** 13 button sites override the theme with `WarmPlayfulRadius.sm` (12) where DESIGN.md says buttons are `md` (16). P2, closed by X-02.
- **Copy tone.** Warm in places ("Say hi 👋", "Meeting up? Stay safe", "Thanks — we'll review this."), generic elsewhere ("Something went wrong — please try again." ×13). Error copy should say what happened and what to do (VERIFY-04, X-07). Consistent "you" voice; button verbs fine. P2.
- **Dates and times.** US formats in a Paris app: "October 6, 2026 at 8:30 PM", chat "7:30 PM", "1/5" for older chats (`core/util/date_format.dart`), while the iOS time picker shows 24 h. Discover/meal cards would read better relative: "Tonight 20:30", "Tomorrow 12:30", "Sat 10 Oct, 20:00". Use `intl` `DateFormat` with the device locale (`intl` must be added as a direct dependency first; P2; part of X-13 if French is chosen, but 24 h and day-month order are worth doing for English too).

### X-13 (P2) Localisation readiness (the decision is the owner's)

State today: English only, **no localisation plumbing at all** (no `flutter_localizations`, no `localizationsDelegates`/`supportedLocales`/`locale` anywhere in `lib/`). Consequences even in English: Material pickers and dialogs render US English and US formats on a French phone ("Tue, Oct 6", `shots/iphone17-light-default__34_create_meal_date_picker.png`); app dates are US ("October 6, 2026 at 8:30 PM", "1/5", `core/util/date_format.dart`, plus a second hand-rolled month list in `age_gate_screen.dart:25-43`).

Hard-coded user-facing strings (grep over `lib/`, approximate): ~78 single-line `Text('…')`/`label:`/`labelText:`/`hintText:`/`tooltip:` literals in 22 files, ~47 multi-line `Text(\n '…')` literals in 20 files, ~20 more in returned/mapped strings (`inbox_action_message.dart` 5, report reasons 5, gender labels 3, relative time 4, version/legal 3), plus 2 month-name tables. **≈ 150 strings (±20), ~25 files.** `settings_screen.dart` (16) and `meal_detail_screen.dart` (18) are the densest.

Rough cost to add French (one language, ARB-based `gen_l10n`):

| Step | Effort |
|---|---|
| Add `flutter_localizations` + `l10n.yaml`, `supportedLocales: [en, fr]` (also fixes picker/dialog locale) | S |
| Extract ~150 strings to `app_en.arb`, replace call sites with `context.l10n.x`, placeholders and plurals ("3 requests") | M (1.5-2 days) |
| Add `intl` as a direct dependency (it is not one today: `date_format.dart:19-20` and `age_gate_screen.dart:40-41` say so), then replace both hand-rolled formatters with `DateFormat` (24 h, day-month), relative day labels | S |
| French copy: translation + native review of tone (warm, informal "tu" vs "vous" is itself a brand decision) | 1 day + reviewer |
| Re-check layouts: French runs ~15-25 % longer; re-run the capture matrix (xxl cells will find the breaks) | S-M |
| Store listing and legal pages in French | outside the app; owner/marketing |

Total ≈ **4-6 developer days plus translation review.** Doing only step 1 + the `intl` date step (≈1 day) is worth it even if the app stays English-only, because it fixes 24 h time and day-month order for Paris users. Decision (English-only vs French at launch, and "tu" vs "vous"): **owner**.

### X-14 (P1) Accessibility semantics (from code)

Only **1** `Semantics` widget (`request_inbox_tile.dart:142`) and **2** explicit tooltips (`discovery_screen.dart:162`, `profile_edit_screen.dart:71`) in the app. Material widgets label themselves where they have text, so most buttons are fine. Gaps visible in code, located on screenshots:

| Gap | Where | Shot | Fix |
|---|---|---|---|
| Rating stars are 5 unlabeled icon buttons: VoiceOver reads "button" ×5, a blind user cannot rate | `rating_sheet.dart:111-125` | `shots/iphone17-light-default__73_rating_sheet.png` | `tooltip: '$i star${i>1?'s':''}'` + `Semantics(selected: i <= _stars)`; wrap the row in `Semantics(label: 'Rating, $_stars of 5')` |
| Send button has no tooltip | `message_composer.dart:101` | `shots/iphone17-light-default__63_chat_messages.png` | `tooltip: 'Send'` |
| Paris notice close, photo remove "x" (also 24 pt) | `paris_notice.dart:57`, `profile_form.dart:335` | `shots/iphone17-light-default__22_discover_data.png`, `__80_profile_edit.png` | `tooltip: 'Dismiss'`, `'Remove photo'` |
| Add-photo tile has no label | `profile_form.dart:363` | `shots/iphone17-light-default__14_profile_setup_empty.png` | visible "Add photo" label (SETUP-01) |
| Unread dot is colour-only, not announced | `chat_list_tile.dart:123-134` | `shots/iphone17-light-default__62_chats_data.png` | `Semantics(label: 'Unread')` on the tile |
| "Women only" label and its `Switch` are separate nodes | `create_meal_screen.dart:214-233` | `shots/iphone17-light-default__36_create_meal_filled.png` | `SwitchListTile` (as the rating sheet already does) |
| Avatars (photos) have no label; the name beside them is read, so `ExcludeSemantics` on the avatar is enough | every `CircleAvatar` | — | `ExcludeSemantics` |
| Async state changes (Requested, Matched, errors) are not announced | meal detail, feeds | `__42`, `__43` | `Semantics(liveRegion: true)` on the status line (MEAL-01) and `ErrorState` |

Text scaling is respected everywhere (no `textScaler` clamps): good, but see X-10. Reduce-motion: nothing to respect yet (X-15).

### X-15 (P2) Motion

DESIGN.md asks for gentle spring motion (`flutter_animate`, `WarmPlayfulMotion`). In the app: page transitions are Cupertino (fine), and there is **no** other motion: no press scale, no state cross-fade on the request button, no list item entrance. `flutter_animate` is a dependency (`pubspec.yaml:50`) with zero uses in `lib/features/` (grep: no `.animate(`, no `AnimatedSwitcher`, no `AnimatedContainer`); `WarmPlayfulMotion` is unused. State changes therefore snap (the request button swaps label and size in one frame, `__40` → `__42`). Recommendation: only functional motion in Part B: `AnimatedSwitcher(duration: WarmPlayfulMotion.fast)` between request states (MEAL-01), skeleton shimmer (X-06), snackbars as-is. Respect `MediaQuery.disableAnimations`. P2.

### X-16 (summary) State completeness matrix

✓ designed and readable · ~ exists but weak (bare text/spinner, unreadable, or not visible) · ✗ missing · n/a. Evidence column = the shot that shows the weakest state.

| Screen | Empty | Loading | Error | Offline | Filled | In-flight action | Evidence |
|---|---|---|---|---|---|---|---|
| Sign-in | n/a | ~ (spinner ends early) | ~ (generic, under keyboard) | ✗ | ✓ | ~ | `__02`, `__03` |
| Phone verify | n/a | n/a | ~ (generic) | ✗ | ✓ | ~ (invisible) | `__05`, `__06` |
| Age gate | ✓ | n/a | ~ (generic) | ✗ | ✓ | ✗ (optimistic, never seen) | `__10` |
| Profile setup | ~ (no guidance) | ~ (photo tile only) | ~ (generic) | ✗ | ✓ | ✗ | `__14` |
| Discover | ~ (one faint line) | ~ (spinner) | ~ (no retry) | ✗ | ~ (meta unreadable) | n/a; refresh ✓ | `__20`, `__21`, `__93` |
| Restaurant search | ~ ("No matches") | ~ (not capturable) | ~ (not capturable) | ✗ | ~ (address unreadable) | n/a | `__31` |
| Create meal | ✓ | n/a | ~ (generic) | ✗ | ✓ | ~ (invisible) | `__37` |
| Meal detail | n/a | ~ (host spinner) | ~ (request state has Retry ✓; host error generic) | ✗ | ~ | ✗ (spinner never shown; rejection feedback unverified) | `__40`, `__49` |
| Requests inbox | ~ (one faint line) | ~ (not capturable) | ~ (no retry) | ✗ | ✓ | ✗ (no spinner, all tiles disabled) | `__54`, `__91` |
| Chats list | ~ (one faint line) | ~ (spinner) | ~ (no retry) | ✗ | ~ (preview unreadable) | n/a | `__60`, `__61`, `__92` |
| Chat | ~ ("Say hi 👋" faint) | ~ (not captured) | ~ (no retry, composer active) | ✗ | ~ (safety card, timestamps) | ✓ send spinner | `__65`, `__66`, `__90` |
| Report sheet | ✓ | n/a | ~ (snackbar) | ✗ | ✓ | ~ (invisible) | `__70` |
| Rating sheet | ✓ | n/a | ~ (snackbar) | ✗ | ✓ | ~ (invisible) | `__75` |
| Profile edit | n/a | ~ (badge collapses) | ~ (generic) | ✗ | ✓ | ✗ (router reset) | `__80` |
| Settings | n/a | ~ ("Loading…" version) | ~ (snackbar on delete) | ✗ | ✓ | ~ (delete ✓, sign out ✗) | `__83` |

(`__NN` = `shots/iphone17-light-default__NN_….png`.) Offline is ✗ everywhere; with Firestore's cache most reads keep working offline, so a dedicated offline UI stays P2/CUT for v1; the `ErrorState` copy (X-07) mentions the connection.

---

## (d) Ranked fix backlog (Part B)

Grouped as spec §3. Within a group, items are in build order. **[owner]** = needs an owner decision before building. "Closes" lists finding ids.

### B1. Theme and tokens (touches everything; do first)

| # | Item | Size | Depends on | Closes |
|---|---|---|---|---|
| B1-1 | **Secondary text token.** Light `muted` → `#7A6352`; `colorScheme.onSurfaceVariant = muted`; replace the 27 text + 8 icon `colorScheme.outline` uses with `wp.muted` (list in X-01); `outline` stays border-only | M | — | X-01, owner ask 1, DISC-01 (colour part), SEARCH-01, MEAL-06, CHATS-01, CHAT-04, AGE-05, VERIFY-05, SIGNIN-07, SET-02 |
| B1-2 | **Button system.** `FilledButton` = primary (coral fill), `onPrimary` = brown `#3D2E1F` both modes, `FilledButton.tonal` secondary, `outlinedButtonTheme` neutral (fixes coral-on-cream labels), radius `md`, new token `WarmPlayfulSize.actionHeight = 56`; remove per-site `styleFrom` overrides (13 sites) | M | B1-1 | X-02, AGE-01, REQ-01, REPORT-02, RATE-02 (fill), PROF-02 (fill), SIGNIN-01, X-12 radius |
| B1-3 | **Container roles + dark parity.** Map `primary/secondary/tertiary/errorContainer`, `inverseSurface`, `snackBarTheme`, chip selected label to palette tokens for both brightnesses | S | B1-2 | X-08, MEAL-03, REQ-06, REPORT-03 (chip), AGE-02/CREATE-03 (picker day) |
| B1-4 | **`dangerText` token** light `#A84A35`; `colorScheme.error` = it for text | S | — | X-04, SET-01 |
| B1-5 | **Shared widgets** in `lib/core/design/widgets/`: `AppButton(isLoading)`, `ErrorState(onRetry)`, `EmptyState`, `SkeletonCard` (uses installed `flutter_animate`) | M-L | B1-2 | X-03, X-06, X-07 (used by B2-B5) |
| B1-6 | **Contrast + token tests**: unit test computing WCAG ratios for every text/background token pair (≥4.5) and UI pairs (≥3.0) in both modes; grep test forbidding `colorScheme.outline` as text/icon colour in `lib/features/` | S | B1-1..4 | locks X-01, X-04, X-08 |
| B1-7 | **Bundle Nunito** (assets + `fontFamily` on every theme style), drop runtime `google_fonts` | S | — | X-05 |
| B1-8 | **Surface separation** ("too bright"): card shadow per DESIGN.md `Card` spec, applied where surfaces are built (shared `AppSurface` replacing the `Material(color: surface)` sites in Discover cards, chat tiles, search rows, composer, add-photo tile; `CardThemeData` alone does not reach them), or deeper `surface #FBE8D8` **[owner: brand]** | S-M | B1-1 | owner ask 1 (brightness) |
| B1-9 | **Router stability**: one `GoRouter`, redirect inputs via `refreshListenable` | M | — | X-09, SETUP-02, PROF-01 |
| B1-10 | **Locale plumbing + `intl` dates** even if English-only: add `flutter_localizations` and `intl` as direct dependencies (neither is one today), then `DateFormat` for 24 h, day-month, relative days | S | — | X-12 dates, CREATE-02, part of X-13 |
| B1-11 | **French** (extract ~150 strings, translate) **[owner: language, tu/vous]** | L | B1-10 | X-13 |

### B2. Onboarding and auth

| # | Item | Size | Depends on | Closes |
|---|---|---|---|---|
| B2-1 | Phone verify: scrollable, auto-submit on 6 digits, back + "Change number", "Resend code" after 30 s, specific error copy | M | B1-5 | VERIFY-01 (P0), VERIFY-02..05 |
| B2-2 | Sign-in: `Flexible` labels, field-level error, spinner held until `codeSent`/`onError`, official Apple/Google buttons, phone input formatter | M | B1-2, B1-5 | SIGNIN-02..06 |
| B2-3 | Age gate: scrollable, year-first picker with "Your date of birth", show blocked message before sign-out | S | B1-2 | AGE-02..04 |
| B2-4 | Profile setup/form: labelled add-photo tile, missing-fields helper, 44 pt remove buttons with tooltips, shorter subtitle, `scrollPadding` | S | B1-1, B1-9 | SETUP-01, 03, 04, 05, PROF-04 |

### B3. Discover and meal flows

| # | Item | Size | Depends on | Closes |
|---|---|---|---|---|
| B3-1 | **Meal detail action bar** (pinned, 56 pt, full width, one state machine, `AnimatedSwitcher`, live-region status line); widget test for the rejected-request snackbar, listener moved to `_RequestAction` if it fails; badge on its own line; hide safety menu on own meal | M | B1-2, B1-3, B1-5 | MEAL-01..05, 07, 08, owner ask 2 |
| B3-2 | Discover cards: one meta line "Tonight 20:30 · 1.3 km", name `maxLines: 2`, host name `Flexible`, bottom padding for FAB, skeleton loading, `EmptyState` with "Create a meal", `ErrorState` | S | B1-5, B1-10 | DISC-01, 03, 05, 06, 07, MEAL-09, ERR-01 (Discover) |
| B3-3 | Paris notice: first list item, persisted dismissal, 44 pt close with tooltip | S | — | DISC-02 |
| B3-4 | Remove sign-out from the Discover app bar | S | B5-1 (Settings keeps it, with confirm) | DISC-04 |
| B3-5 | Create meal: `AppButton` loading, :00/:30 default time, clearer success copy | S | B1-5, B1-10 | CREATE-01, 02, 04 (copy) |
| B3-6 | Restaurant search: muted addresses, helpful empty copy, skeleton/`ErrorState` | S | B1-5 | SEARCH-01, 02 |

### B4. Requests, chat, ratings, safety

| # | Item | Size | Depends on | Closes |
|---|---|---|---|---|
| B4-1 | **Chat layout**: safety tips → one-line banner + sheet (and Settings page); post-meal card → first list item; meal context header; message list is the only flexible child | M | B1-5 | CHAT-01 (P0), CHAT-02, CHAT-03, RATE-02 (layout), RATE-04 |
| B4-2 | **Sheets scroll with the keyboard** (report + rating), `textInputAction: done`, named titles, readable unselected stars | M | B1-2 | REPORT-01 (P0), RATE-01, REPORT-03, RATE-03 |
| B4-3 | Requests: per-request pending state with spinner in the pressed button, `OverflowBar`, Deny as danger text button, guest `RatingBadge`, inbox icon | M | B1-2, B1-5 | REQ-02..05 |
| B4-4 | Chat polish: day separators + grouped timestamps, clear composer immediately, `ErrorState` replacing the list on error | M | B1-5 | CHAT-05..07 |
| B4-5 | Block dialog names the person, danger confirm | S | B1-4 | REPORT-04 |
| B4-6 | Feed `ErrorState` + skeletons for Requests and Chats lists, `EmptyState`s | S-M | B1-5 | ERR-01, CHATS-02 |
| B4-7 | Accessibility labels (stars, send, unread, avatars excluded, live regions) | S | — | X-14 |

### B5. Profile and settings

| # | Item | Size | Depends on | Closes |
|---|---|---|---|---|
| B5-1 | Settings restructure with existing items + Edit profile row, read-only phone, Sign out confirm/progress, Safety tips page, Contact (mailto), Licences | S | B1-1 | SET-02, SET-03, owner ask 4 (part) |
| B5-2 | Blocked people screen (list + Unblock; repository and rules already support it) **[owner: confirm in scope]** | M | B5-1 | owner ask 4 |
| B5-3 | Profile edit: Save enabled only when dirty, "Profile saved" snackbar instead of pop, title "Profile", labelled rating | S | B1-9 | PROF-02, PROF-03 |
| B5-4 | Notification controls, change phone number, language switch **[owner: new scope, default CUT]** | M-L each | — | owner ask 4 (rest) |

Every item ships with widget tests at 320 px width and `TextScaler.linear(2.0)` where layout is involved, and is verified against a fresh `make ux-capture` run.

**Owner decisions needed:** (1) French at launch, and tu/vous (B1-11); (2) Settings scope beyond the recommended set: notification controls, change phone, language (B5-4); confirm Blocked people (B5-2); (3) brand-level token changes: deeper `surface` (B1-8) and, only if wanted, a darker coral fill for ≥3:1 buttons on cream (X-02); (4) a "My meals" list for hosts (CREATE-04, new scope, default CUT).

---

## (e) Appendix

### Shots viewed (98 of ~520)

- `iphone17-light-default` (61): 01, 02, 03, 04, 05, 06, 10, 11, 12, 14, 15, 16, 20, 21, 22, 23, 25, 26, 30, 31, 33, 34, 35, 36, 37, 40, 42, 43, 44, 45, 46, 47, 48, 49, 52, 54, 55, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 80, 81, 83, 85, 90, 91, 92, 93. Not opened: 24, 32, 51, 53 (variants of viewed states; the Requests empty state is judged from code and the identical Chats empty state, and is not cited).
- `iphone17-dark-default` (16): 01, 05, 11, 12, 14, 22, 26, 40, 42, 43, 52, 62, 63, 69, 73, 83.
- `iphone17-light-xxl` (12): 01, 04, 05, 14, 22, 24, 40, 44, 66, 69, 72, 83.
- `se3-light-default` (5): 22, 40, 63, 69, 74.
- `se3-light-xxl` (4): 10, 46, 52, 63.

`*-dark-xxl` and `se3-dark-*` cells were not opened: their findings logs mirror the light cells line for line, and the dark default cells already establish the colour behaviour. This is below the 120-180 budget the brief allowed; I stopped where additional shots repeated a finding already evidenced (the run was also interrupted once by a rate limit).

### Could not be assessed, and why

| What | Why | Nearest evidence |
|---|---|---|
| Under-18 blocked screen | unmounted by sign-out before it renders (README "Not captured") | `__12_age_gate_under18_selected`; AGE-04 |
| Age gate / setup Continue, profile Save, Request to join **in flight** | optimistic local write moves the UI on first | `__42`; X-06 rows 5, 7, 8, 15 |
| `06_phone_verify_error` at xxl | Verify unreachable under the keypad (that is VERIFY-01) | `shots/iphone17-light-xxl__05_phone_verify_in_flight.png` |
| Requests-inbox loading, restaurant-search loading/error | preloaded by the tab badge / in-memory fake | code only |
| Google/Apple sign-in in flight, photo picker, notification and location alerts, Privacy/Terms pages | native surfaces | — |
| Location-denied banner, offline UI | do not exist in the app | X-16 |
| VoiceOver behaviour | screenshots cannot show it; X-14 is from code | X-14 |
| The 195/222 px right overflow at xxl on meal detail | no stripe in the visible viewport; source inferred | MEAL-09 |
| Exact contrast of anti-aliased rendering | ratios are computed from tokens, not sampled from PNGs | `docs/ux/contrast-measured.txt` |
| Android | out of scope for this pass (spec §4) | — |

Hand-computed ratios in this document (WCAG relative luminance from hex): `#7A6352` on `#FFFAF3` 5.42, on `#FFF1E6` 5.08; `#A84A35` on bg 5.47, on surface 5.13; brown `#3D2E1F` on dark coral `#FF9F8C` 6.58; light surface vs bg 1.07; dark surface vs bg 1.11; `#FBE8D8` vs bg 1.15, new muted on it 4.72, text on it 10.96; `#B84A36` vs bg 4.97 (cream label on it 4.97). Method check: the same computation reproduces the measured `muted on bg` 4.18. They should be asserted by B1-6 before they are relied on.
