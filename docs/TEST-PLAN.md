# Test Plan

The canonical checklist `qa-engineer` runs before any release. Living document — grow it as features ship.

> **Rule:** No release ships without a green run of this plan on iOS Simulator + Android Emulator + at least one real device.

---

## How to use this file

1. Per feature, add a section under § Feature checklists. Use the template below.
2. Before each release, `qa-engineer` runs every box. Any fail → file a bug via `/bug`, link the slug back here.
3. Move features from "active" to "stable" once they've passed 3 consecutive releases with no regression bugs filed.

---

## Test categories (Flutter)

The pyramid for this template — write the cheap ones first, fall back to the expensive ones only when you must.

| Category | Tool | Runs in | When to use |
|---|---|---|---|
| **Unit** | `flutter_test` | Pure Dart | Notifier logic, repositories with mocked Firestore, pure functions |
| **Widget** | `flutter_test` + `ProviderScope` test harness (`test/helpers/pump_app.dart`) | Flutter test renderer | Single screen / widget behavior, state transitions, golden path of a feature |
| **Golden** | `flutter_test` (`matchesGoldenFile`) | Flutter test renderer | Visual regressions on key screens — run on one host platform only (CI matrix pinned) |
| **Integration** | `integration_test` package | Real simulator/emulator | End-to-end golden flows (sign-in, create-first-thing, etc.) |

**Rule:** Mocks via `mocktail` only. Register fallback values for non-primitive matchers in `setUpAll`. No codegen-based mocks.

---

## Universal edge cases (run for every release)

Failure modes that bite mobile + Firebase apps regardless of feature:

### Data + time

- [ ] Timezone math. Date-keyed data must respect local TZ, not UTC.
- [ ] Date rollover at midnight — "today" advances without manual refresh. — re-verified 2026-10-12 (code): fixed, `discovery_clock_edge_test.dart` drops started meals by timer (see `docs/bugs/closed/2026-10-09-discovery-feed-stale-and-unbounded.md`); on-device NOT VERIFIED HERE
- [ ] DST transition — math still correct on clock-change days.
- [ ] Long strings (≥1000 chars) in text fields don't crash.
- [ ] Long lists (≥100 items) render without dropped frames.
- [ ] `Timestamp` → `DateTime` conversion uses the registered `JsonConverter` everywhere (no raw `.toDate()` calls leaking into models).

### Network

- [ ] Offline write queues (toggle airplane mode mid-action). — re-verified 2026-10-12: chat, create meal, request, rating use `settleOrQueue` (fixed, `docs/bugs/closed/2026-10-09-awaited-writes-block-ui-offline.md`); **FAIL (code)** for Report and Block, which still await the server: `docs/bugs/2026-10-12-report-and-block-spin-forever-offline.md`; airplane mode NOT VERIFIED HERE
- [ ] Reconnect syncs queued writes.
- [ ] Slow network throttle (Network Link Conditioner / Android emulator throttle) doesn't break UI.
- [ ] Firestore cache renders previously-fetched data on cold offline launch.

### Auth

- [ ] Anonymous → real-account linking preserves uid + data.
- [ ] Sign-out clears all local state (Riverpod providers invalidated, in-memory caches dropped). — re-verified 2026-10-12: providers fixed (`docs/bugs/closed/2026-10-09-providers-survive-sign-out.md`); the on-disk Firestore cache is not cleared (P3 in `docs/bugs/2026-10-12-minor-findings-second-sweep.md`)
- [ ] Account deletion cascade leaves zero orphan docs. — re-verified 2026-10-12 against the Firestore emulator (`firebase/functions/test-emulator/state_machine.test.cjs`): a guest leaving reopens a future meal / cancels a past one, flags cleared (`docs/bugs/closed/2026-10-09-deleted-guest-strands-hosts-matched-meal.md`); non-atomic window: `docs/bugs/2026-10-12-cancel-meal-can-leave-a-stale-match-that-blocks-rematching.md`; Storage + Auth deletion NOT VERIFIED HERE
- [ ] Token refresh works after 1h+ idle.

### Permissions

- [ ] Push notification permission denied — feature still works, nudges silently disabled.
- [ ] Camera/photo permission denied — graceful fallback.

### Lifecycle

- [ ] Cold start (after force-kill) reaches the right screen within 3s on mid-tier Android. — timing NOT VERIFIED HERE; **FAIL (code)** for the screen itself: sign-in / age gate flash while the session or user doc loads, `docs/bugs/2026-10-12-router-flashes-signin-and-age-gate-while-session-loads.md`
- [ ] Background → foreground after 10+ min doesn't crash or duplicate state.
- [ ] Deep link cold-opens app to the linked screen (go_router `initialLocation` path). — **FAIL (code)** for push taps: chat opens with no back navigation, `docs/bugs/closed/2026-10-12-push-tap-strands-user-in-chat-without-back.md`

### Memory + perf

- [ ] 5 min of typical use → no obvious memory growth (DevTools memory tab).
- [ ] No Firestore listener leaks — every `.snapshots()` subscription is owned by a Riverpod provider that auto-disposes. — re-verified 2026-10-12: per-user family providers auto-dispose; `hostInboxProvider`, `blockedUserIdsProvider`, `chatListProvider`, `currentUserDocProvider` and the discovery feed are app-lifetime by design and re-subscribe on auth change (`docs/bugs/closed/2026-10-09-providers-survive-sign-out.md`)

### Security

- [ ] Firestore rules deny reads of another user's data (test via Rules Playground or emulator). — verified on the emulator 2026-10-09 (72 cases) and again 2026-10-12 (`hardening`, `users_profiles`, new `client_write_shapes`: 19 passed, 3 skipped for open bugs `docs/bugs/closed/2026-10-12-one-malformed-meal-breaks-discover-for-everyone.md`, `docs/bugs/2026-10-12-requests-rule-lets-a-guest-break-the-hosts-inbox.md`, `docs/bugs/2026-10-12-minor-findings-second-sweep.md`) for requests, matches, messages, reads, fcmTokens, blocks, reports, ratings; `users/{uid}` was open (incl. dob) — **fixed**: private `users` + public `profiles`, rules tests in `firebase/rules-test/`; see `docs/bugs/closed/2026-10-09-users-collection-exposes-dob-to-all-signed-in-users.md`; hardening gaps in `docs/bugs/closed/2026-10-09-firestore-rules-hardening-gaps.md`
- [ ] `.env` is gitignored — `git log --all -p -- .env` returns nothing.
- [ ] No `cloud_firestore` imports outside a feature's `data/` layer or `lib/core/firebase/` (the old grep in this line contradicted the architecture; see `docs/bugs/closed/2026-10-09-docs-contradict-code.md`). Checked 2026-10-09: clean.

### Visual + a11y

- [ ] Dark mode parity for every shipped screen (both `ThemeMode.light` and `ThemeMode.dark`). — NOT VERIFIED HERE: only meal detail, buttons and contrast tokens have dark-mode tests; no per-screen goldens
- [ ] Dynamic type at 200% (`MediaQuery.textScaler`) doesn't truncate critical text. — re-verified 2026-10-12 (harness, real Nunito): sign-in, sheets, age gate, chat pass (`docs/bugs/closed/2026-10-09-text-scale-overflow-signin-and-sheets.md`, `docs/bugs/closed/2026-10-09-chat-keyboard-squeezes-message-list.md`); other screens and a real device NOT VERIFIED HERE
- [ ] Screen reader (VoiceOver / TalkBack) reaches every action — every interactive widget has a `Semantics` label or wraps a Material widget that provides one. — **FAIL (code)**: rating stars, chat send, Paris notice close, add-photo tile have no accessible name: `docs/bugs/closed/2026-10-12-icon-only-controls-have-no-screen-reader-label.md` (`test/core/a11y/`); screen-reader pass NOT VERIFIED HERE

### Design system (UX plan 16a) — automated, `test/core/design/`

- [x] `contrast_test.dart` — text/background token pairs (muted, onAccent, dangerText, error, snackbar action) reach WCAG AA in light and dark.
- [x] `button_theme_test.dart` — filled/tonal/outlined/elevated/FAB/nav-bar/segmented/chip colours, min height 48 on filled/elevated/outlined, disabled states, in-flight spinner contrast (>= 3:1) in both modes.
- [x] `switch_theme_test.dart` — Switch on/off thumb, track and outline (>= 3:1), SegmentedButton off outline, chip checkmark (>= 4.5:1), TextButton >= 48 high.
- [x] `no_border_colour_as_text_test.dart` — no `colorScheme.outline` (the border token) used as a text or icon colour under `lib/features` (`outlineVariant` is not guarded; only two sign-in dividers use it).
- [x] `container_roles_test.dart` — primary/tertiary/error/inverse container roles, snackbar and chip colours.
- [x] `typography_test.dart` — every text style is Nunito; each pubspec font entry maps its file to its weight (400/500/700/800); `google_fonts` is gone; `bootstrap()` registers the OFL (call-site guard; `registerFontLicense` itself is unit-tested).
- [x] `card_separation_test.dart` — card theme and card files carry elevation + shadow + transparent tint; border token >= 1.1:1 on surface.
- [x] `profile_form_test.dart` — add-photo tile outline reaches 3:1 on its surface.
- [ ] Manual: `make ux-capture` before/after comparison (see `docs/ux/16a-verification.md`).

### Shared widgets, router, dates (UX plan 16b) — automated

- [x] `test/core/design/widgets/app_button_test.dart` — four variants render at >= 48 high (56 for primary/tonal), loading keeps the enabled fill and a visible spinner, swallows taps, is a live-region semantics node with the loading label, idle size == loading size (also at 2.0x text, 320 px, light and dark).
- [x] `empty_state_test.dart`, `error_state_test.dart` — render, Try again fires `onRetry` once, title colour (default for errors, muted for empties), muted body/icon in light and dark, title+message announced as one live region, 2.0x text at 320 px (with animations on), no overflow.
- [x] `skeleton_card_test.dart` — `wp.border` blocks, configurable lines/avatar, shimmer runs and stays off with `disableAnimations`, highlight lighter than the blocks in both modes, `SkeletonList`/`SkeletonMessages` announced as "Loading", no overflow in a tight box and at 2.0x.
- [x] Feed screen tests (`discovery_screen_test`, `request_inbox_screen_test`, `chat_list_screen_test`, `chat_screen_test`, `restaurant_search_screen_test`) — skeleton while loading, `ErrorState` with a working Try again, empty state.
- [x] `test/core/routing/router_stability_test.dart` — same `GoRouter` instance across auth and non-redirect user-doc emissions, redirect chain (signin -> age gate -> profile -> Discover and back), `profileComplete` flips navigate, a profile TextField keeps its text across a user-doc change, a direct user-A-to-user-B auth emission drops A's pushed route (`/settings`) and lands on `/discover` (mutation-checked).
- [x] `test/core/util/date_format_test.dart` — Today/Tomorrow/absolute/year forms, UTC instants placed on their LOCAL day, DST-safe, real-clock case retried across midnight. CI re-runs this file (and the chat/request tile tests) under `TZ=Pacific/Kiritimati` so a UTC-vs-local bug cannot pass vacuously.
- [ ] Manual: `make ux-capture` before/after comparison (see `docs/ux/16b-verification.md`). Only the capture shows how it looks and the profile-setup form surviving a photo write.

**E2E caveat (loading indicators):** `integration_test/` waits with a bounded hand-rolled settle, never `pumpAndSettle()` with its 10-minute default, because a loading indicator or skeleton shimmer never settles (and `flutter_animate` leaves a pending timer). Any new E2E that waits for a feed to load must pump on a duration and wait for the loaded widget, not for the tree to go idle. Skeletons replaced the old spinners, so E2E finders must not look for a `CircularProgressIndicator` as a loading marker; the in-button spinner is still one (inside `AppButton`).

**E2E caveat (switching users):** the router is built once and only reacts to a flip of `signedIn`/`ageVerified`/`profileComplete`. A scenario that signs out and straight back in as someone else on a mounted app must use `signOutAndAwaitSignIn(tester)` (`integration_test/support/auth.dart`), which waits for the sign-in screen; with `signOutTestUser()` alone the router never sees the signed-out state and the previous user's route (a chat, a rating sheet) stays on screen. A real user always passes through the sign-in screen.

### Sign-in, phone code, age gate, profile setup (UX plan 17a) — automated

- [x] `test/features/auth/presentation/signin_screen_test.dart` — with a 300 px keyboard at 320 x 568 and 2.0x text the field, its error and Send code scroll above the keyboard (mutation-checked); a `codeSent` after the 60 s timeout never opens the code screen; Apple fires `signin_started(apple)` once and is disabled for screen readers while another method is busy; implausible number refused locally with the hint on the field (repository not called) and the field refocused; number sent as E.164 without spaces and without a trunk 0; spinner held until `codeSent` / `onError` / 60 s timeout; late `codeSent` of a superseded attempt ignored; generic error is a live region; under-18 banner (shown, dismissed, cleared by any sign-in start); official Apple button (label, black/white by theme, dimmed and inert while busy, "Signing in…" node).
- [x] `test/features/auth/presentation/phone_verify_screen_test.dart` — layout at 320 px / 2.0x text / keyboard 260; header with "Sent to +33 6 12 34 56 78", Change, back; 6th digit submits once (also with Done); "Verifying…" and stable button size; Verify stays locked after success; wrong code vs other failures; resend cooldown from a deadline (clock jump), swap of the verification id, 60 s resend timeout, stale attempts ignored, "Code sent again", failure sentence.
- [x] `test/features/auth/data/auth_repository_impl_test.dart` — `confirmSmsCode` maps invalid-verification-code / invalid-verification-id / session-expired to `InvalidSmsCodeException` and rethrows everything else. `test/core/util/phone_test.dart` — `toE164` (spaces/hyphens, French trunk 0 only, `+39 06…` keeps its 0, validates the normalised number), `isPlausiblePhone`, `formatPhoneDisplay`. `test/features/onboarding/application/underage_notice_provider_test.dart`.
- [x] `test/features/onboarding/presentation/age_gate_screen_test.dart` — 320 px / 2.0x no overflow, Continue reachable and submits; centred when it fits; the real picker opens on the year grid with the help text and the typed-entry label; "Saving…". `age_gate_controller_test.dart` — notice set BEFORE `signOut`, not set for adults, reset when `signOut` fails, a stale notice cleared before an adult upsert.
- [x] `test/features/onboarding/presentation/profile_setup_screen_test.dart`, `test/features/user/presentation/profile_form_test.dart` — `missingFields` order, "Still needed" line (3, 2 and 1 missing; live region; below Continue; hidden when valid), labelled add-photo tile (semantics, icon / spinner colour, "Uploading photo" while busy), remove button (48 hit area, 24 visual, tooltip as its name), `kProfileFieldScrollPadding` on both fields, typing at the end of Bio on a 320 x 480 viewport at 2.0x text with a 200 px keyboard keeps Continue above the keyboard (mutation-checked: fails without the scroll-into-view), no overflow at 320 px / 2.0x. `router_stability_test.dart` — `/auth/phone` without `PhoneVerifyArgs` falls back to sign-in.
- [x] `test/core/design/widgets/app_button_test.dart` — the `height` override keeps idle and loading the same size.
- [ ] Manual: `make ux-capture` before/after comparison (see `docs/ux/17a-verification.md`). Only the capture shows how these screens look in both themes, at the small phone with large text, and the real native Apple button.

**Manual QA steps for 17a (cannot run headless; user-run on a device or simulator):**

- [ ] **VoiceOver, AppButton idle to loading.** iPhone with VoiceOver on: on the sign-in screen focus "Send code" (spoken as a button), double-tap with a valid number: the spinner replaces the label and VoiceOver announces "Sending code…" once, as a disabled button, without losing focus; on the code screen type six digits: "Verifying…" is announced; a wrong code announces the field error and focus returns to the field. Same idle to loading to idle check for "Continue" on the age gate and profile setup ("Saving…"). (Widget tests pin the semantics tree, not what VoiceOver speaks.)
- [ ] **Apple button label at 320 pt.** On an iPhone SE class device (or the "Convyve UX Small" simulator) with the largest accessibility text size: "Continue with Apple" is fully visible, not wrapped or clipped (the package fixes the label at 0.43 x the 56 pt height and the screen caps its text scale at 1x), in light and dark.
- [ ] **Android phone auto-verification.** On a real Android device whose SIM receives the SMS (or an instant-verification test number): Firebase can call `verificationCompleted` without ever calling `codeSent`. In the code, `AuthRepositoryImpl.verifyPhone` then signs in with the credential (`signInWithCredential`, not awaited) and does not call the screen back, so the sign-in screen keeps its "Sending code…" spinner until the router leaves it (signed in -> age gate or Discover). Expected: the spinner stays, then the app moves on; no code screen is shown. If `signInWithCredential` fails, nothing is reported either: the spinner stays until the 60 s timeout shows "Something went wrong — please try again." Check both and decide whether the failure should be surfaced (not changed in 17a).
- [ ] **Focusing fields scrolls Continue into view (real device).** Profile setup on a small iPhone and a mid-size Android with the software keyboard: tap Name, then Bio, type a few lines: Bio's caret stays visible and Continue (plus the "Still needed" line) can be reached without dismissing the keyboard; repeat with the largest text size. Widget tests simulate the keyboard inset only.

### Discover, meal detail, create meal, restaurant search (UX plan 17b) — automated

- [x] `test/features/meal/presentation/meal_action_bar_test.dart` — every viewer state (own, women-only, loading, load error, none, pending, approved, denied) renders its label, key and status copy; the bar has exactly the same height in all of them at 1.0x, 1.3x and 2.0x text on 320 x 568 (no overflow, no button label ellipsized or clipped, scroll body at least 220 px); the status line is one live-region node whose label is the full sentence; "Open chat" opens `/chats/{mealId}`; a failed request shows the "Couldn't send your request. Try again." snackbar even though the button was swapped for "Requested", and "This meal is no longer open." when the error is `MealNoLongerOpenException`. `meal_detail_button_test.dart` — request flow through the screen. `test/core/design/widgets/app_button_test.dart` — `maxLines` and the loading label.
- [x] `test/features/meal/presentation/discovery_screen_test.dart`, `paris_notice_test.dart` — card anatomy (one `<when> · <distance>` line, `Wrap` for the badge), the last card clears the FAB, empty state with its Create-a-meal action, long names ellipsize at 320 px / 2.0x while the meta text wraps to two lines (distance kept), no FAB on the empty state (one Create-a-meal button), the notice scrolls with the list and is shown above loading / empty / error, dismissal keeps the state. `settings_screen_test.dart` — sign-out is confirmed in a dialog, unregisters the push token (`unregisterCurrentToken(uid)` exactly once, mutation-checked) and signs out, also when the screen unmounts while the dialog is open.
- [x] `test/features/meal/presentation/create_meal_screen_test.dart` — `nextMealSlot` (now + 1 h rounded UP to :00 / :30, seconds, midnight; never before now + 1 h and less than 30 min later), the time picker opens on a slot and is 24 h, the success snackbar "Meal posted. You'll get requests in the Requests tab.", the note field's `scrollPadding` is `WarmPlayfulSize.keyboardReveal` (mutation-checked), Create meal reachable at 320 x 568 / 2.0x text with the keyboard up.
- [x] `test/features/meal/presentation/restaurant_search_screen_test.dart` — "No restaurants to show yet." for an empty list before any query, "No restaurant called “<query>”. Try another name." after one, wrapped inside the margins at 320 px.
- [ ] Manual: `make ux-capture` before/after comparison (see `docs/ux/17b-verification.md`).

**Manual QA steps for 17b (cannot run headless; user-run on a device):**

- [ ] **VoiceOver, action bar status.** Meal detail with VoiceOver on: Request to join is a button; double-tap: the spinner replaces the label, VoiceOver announces "Sending request…" as a disabled button; when the host approves (admin write or second device) the status "You're matched. Say hi!" is announced by itself and "Open chat" is focusable. Swipe to the status line: the whole sentence is read as one node even when it is cut with an ellipsis on screen.
- [ ] **Action bar at large text (real device).** Set the largest text size on a small iPhone and a mid-size Android: "Request to join", "Sending request…", "This is your meal", "Open chat", "Not selected" are shown whole (they may wrap to two lines), the bar keeps one height between states and the page above it still scrolls.
- [ ] **Open in Maps still works.** From the restaurant card above the pinned bar: tap "Open in Maps", the maps app opens on the venue (the card moved up, the button is unchanged); no snackbar.
- [ ] **Pull-to-refresh in the empty and error states.** Discover with no meals nearby (and with the network off for the error state): pull down: the spinner shows, the empty / error state stays (no crash), and Try again behaves like a pull.
- [ ] **Notice and FAB.** Dismiss the Paris notice: it is gone until the next launch (per session by design). Scroll to the end of a long feed: the last card is fully visible above "Create a meal". With no meals nearby there is one "Create a meal" button (in the empty state), not two.
- [ ] **Rejected request.** Open a meal, have the host (or an admin write) match it, then tap Request to join: the snackbar "Couldn't send your request. Try again." appears, about one second after the tap. (The specific "This meal is no longer open." copy never shows yet: `createRequest` wraps every failure; follow-up.)

### Requests, chat, sheets, Settings, profile (UX plan 18) — automated

- [x] `test/features/matching/presentation/widgets/request_inbox_tile_test.dart`, `request_inbox_screen_test.dart`, `application/controllers_test.dart` — Approve is the coral primary `AppButton` and Deny a text-variant `AppButton` in `dangerText` (>= 4.5:1 both modes); busy state is per request (spinner only in the pressed button of that tile, other tiles tappable, two concurrent actions kept apart); the pair stacks at 320 px / 2.0x (no overflow, both >= 48 high); `RatingBadge` under the guest name; loading labels "Approving…" / "Denying…"; past meal keeps Approve disabled; unmount mid-flight still shows the snackbar. `app_shell_test.dart`: Requests tab uses the inbox icon, badge only for a nonzero count.
- [x] `test/features/chat/presentation/chat_screen_ux_test.dart`, `widgets/group_messages_test.dart`, `message_bubble_test.dart`, `message_composer_test.dart`, `chat_list_tile_test.dart`, `chat_list_screen_test.dart`, `test/core/util/date_format_test.dart` — safety banner (not a `Card`, one line, opens the sheet, dismiss), banner and meal header hidden with the keyboard, meal header text/tap/absent, day separators and time only on the last bubble of a run, the post-meal card scrolls with the list (keyboard open: hidden; short viewport: above the oldest message; prompt event once), composer clears at once and restores on failure and is absent when messages fail to load, chat-list meal line and "Find a meal" empty state, `formatDayLabel` (Kiritimati and Los Angeles groups).
- [x] `test/features/safety/presentation/report_sheet_copy_test.dart`, `safety_actions_block_test.dart`, `safety_tips_banner_test.dart`, `safety_tips_screen_test.dart`, `test/features/rating/presentation/rating_sheet_copy_test.dart`, `post_meal_card_test.dart` — sheet and dialog titles name the person with the generic fallbacks, note-field edge >= 3:1, selected chip label >= 4.5:1, star contrast and semantics, block confirm in `dangerText`, post-meal card layout (Row up to 1.3x, Column above; no overflow at 320 px / 2.0x).
- [x] `test/features/safety/presentation/blocked_people_screen_test.dart`, `data/block_repository_impl_test.dart`, `application/blocked_by_me_provider_test.dart` — list, empty, loading skeleton and error states, per-row "Unblock <name>" semantics and "Unblocking…" busy state, snackbar "Unblocked <name>.", stacked button above text scale 1.3, and the Firestore query shape (`pair array-contains uid`, never a `blockerUid ==` query: mocktail spy, the rules cannot prove it).
- [x] `test/features/settings/presentation/settings_screen_test.dart` — group order and headers, phone row only when the sign-in has a number, notification row only on iOS and opening `app-settings:`, licence page, Delete account last, 48 dp rows, no overflow at 320 px / 2.0x, existing `settings_*` keys kept.
- [x] `test/features/user/presentation/profile_edit_screen_test.dart` — Save only when name/bio/gender changed (trimmed), never for a photo-only change, never for a blank name (and "Still needed: your name." says so, no hint when merely unchanged), a cleared bio is sent as '' and persisted (`user_repository_impl_test.dart`), "Profile saved" and Save disabled again, typed text survives a user-doc re-emit, failed save keeps the form and a retry works, rating row at 320 px / 2.0x with label and value on screen. `meal_action_bar_test.dart`: "Meal cancelled" state and equal bar height.
- [ ] Manual: `make ux-capture` before/after comparison (see `docs/ux/18-verification.md`).

**Manual QA steps for 18 (cannot run headless; user-run on a device):**

- [ ] **VoiceOver, inbox.** Requests tab with two pending requests: Approve and Deny are buttons; double-tap Approve: VoiceOver announces "Approving…" (disabled) on that tile only, the other tile's buttons stay focusable; a past-meal request reads Approve as dimmed with "Meal time has passed". Swipe over the guest row: the name is followed by the rating.
- [ ] **VoiceOver, chat.** The meal header reads as a button ("Restaurant · date") and opens the meal; the safety banner is a button that opens the tips sheet, its X is "Dismiss safety tips"; day separators ("Today", "Yesterday") are read in order between messages; "Rate <name>" reads the name.
- [ ] **VoiceOver, blocked people.** Each row's button reads "Unblock <name>" (not just "Unblock"), becomes "Unblocking…" while busy, and the snackbar "Unblocked <name>." is announced.
- [ ] **Settings headers.** With VoiceOver, the rotor "Headings" lists Account, Safety, Notifications, Legal, About.
- [ ] **Blocked people on a real account.** Block someone from a chat, open Settings > Blocked people: they are listed with their name and photo; Unblock removes the row, and the person can message / see you again (second device). Block three people and unblock the middle one. Airplane mode: Unblock is queued, not stuck on a spinner.
- [ ] **Notification settings (iOS only).** Settings > Notification settings ("Manage notifications in iOS Settings") opens the iOS Settings page for Convyve. On Android the row is not shown.
- [ ] **Licences.** Settings > Open-source licences opens the licence page titled Convyve with the app version; back returns to Settings.
- [ ] **Profile Save flow.** Profile tab: Save is dimmed on open; type a letter in the name: Save lights up; delete the name: Save dims and "Still needed: your name." appears; restore the name: back to dimmed; change the bio, Save: "Profile saved" snackbar, you stay on the tab and Save dims. Add a photo: it appears at once and Save stays dimmed. Airplane mode + Save: the error shows, the typed text stays, Save works after going online.
- [ ] **Cancelled meal.** Host cancels a matched meal from the chat; the guest taps the meal header in the chat: the meal page shows "Meal cancelled" and "The host cancelled this meal." (a screen already open on the meal does not update until reopened: known).
- [ ] **Large text.** Largest text size on a small iPhone: inbox buttons stack with Approve on top, the chat post-meal card shows the Rate button full width below the text, the rating row on Profile wraps, and Settings and Blocked people rows stay readable.

---

## Feature checklists

Add one section per shipped feature. Template:

### Feature: {{feature-name}}

Status: active | stable | retired
Related PRD entry: `docs/PRD.md § Feature: {{feature-name}}`

**Golden path:**
- [ ] {{step 1 + expected result}}
- [ ] {{step 2 + expected result}}

**Edge cases (specific to this feature):**
- [ ] {{edge case 1}}
- [ ] {{edge case 2}}

**Known issues:**
- {{link to active bug docs/bugs/<date>-<slug>.md if any}}

---

### Feature: Auth & 18+ onboarding

Status: active
Related PRD entry: `docs/PRD.md § Auth`

**Golden path:**
- [ ] Signed-out launch lands on `/auth/signin` (verified 2026-09-19, iOS Simulator, stage flavor — screen renders Google/Apple/phone, phone defaults to +33).
- [ ] Google sign-in (iOS stage) → age gate on first run → home. *(Needs a real Google account tap; not automatable — run manually.)*
- [ ] New user hits the 18+ age gate; DOB ≥ 18 → writes `users/{uid}` (ageVerified) → home; DOB < 18 → blocked message + auto sign-out.
- [ ] Returning verified user skips the age gate → straight to home.
- [ ] Sign out → returns to `/auth/signin`.
- [ ] Phone: `+33` number → "Send code" → OTP screen → verify → age gate/home. *(Needs APNs + a real SMS — pending native setup.)*

**Edge cases (specific to this feature):**
- [ ] DOB exactly 18 today = allowed; one day short = blocked (unit-tested in `age_test.dart`).
- [ ] DOB stored UTC-midnight — no timezone day-drift on read (unit-tested in `users_repository_test.dart`).
- [ ] Malformed `users` doc surfaces `RepositoryParseException`, not a raw crash.
- [x] Non-owner cannot read/write another user's private `users/{uid}` doc; other users can `get` (not list) the public `profiles/{uid}` only (Firestore rules; `firebase/rules-test/`).
- [ ] Redirect never loops across signin / age-gate / home / OTP (unit-tested in `redirect_test.dart`).

**Pending native config (blocks live tests):**
- Apple sign-in: provider + App ID capability not yet enabled.
- Phone: APNs auth key (iOS), Android SHA-256 + Play Integrity not yet registered.

**Known issues:**
- `docs/bugs/closed/2026-10-09-users-collection-exposes-dob-to-all-signed-in-users.md` (P1, fixed) — private/public split; rules tests in `firebase/rules-test/`
- `docs/bugs/closed/2026-10-09-router-rebuilt-on-every-user-doc-change.md` (P1, fixed)
- `docs/bugs/closed/2026-10-09-text-scale-overflow-signin-and-sheets.md` (P2)
- `docs/bugs/2026-10-12-router-flashes-signin-and-age-gate-while-session-loads.md` (P2, open)

---

### Feature: Profile

Status: active
Related PRD entry: `docs/PRD.md § Profile`

**Golden path:**
- [ ] After the 18+ gate, an incomplete-profile user is forced to `/onboarding/profile` (routing unit-tested); cannot reach home or skip.
- [ ] Setup: enter displayName + pick ≥1 photo + select gender → Continue enables → profile saved (`profile_completed` fired) → router advances to home.
- [ ] Returning complete-profile user skips setup → straight to home.
- [ ] Edit (settings) → change name/bio/gender/photos → Save persists (partial merge, doesn't clobber dob/ageVerified).
- [ ] Photo upload works end-to-end (needs Storage enabled + a real image). *(Blocked until Storage bucket + rules deployed — see below.)*

**Edge cases (specific to this feature):**
- [ ] `profileComplete` = name non-blank && ≥1 photo && gender set (unit-tested).
- [ ] Photo cap: 6 max; add tile hidden/disabled at 6 (controller no-ops at ≥6).
- [ ] Remove photo updates the doc before deleting the Storage object (no dangling URL).
- [ ] DOB is not editable in the profile (age shown, derived).
- [ ] Non-owner cannot write another user's photos (Storage rules: owner-only write, signed-in read).
- [ ] Env-prefixed Storage paths (`stage/` vs `prod/`) keep flavors apart in the shared bucket.

**Pending (blocks live photo tests):**
- Firebase **Storage not yet enabled** on the project — click "Get Started" in the console, then `firebase deploy --only storage`. Until then, `upload()` I/O is unverified (only path-building + delete are unit-tested).

**Known issues:**
- `docs/bugs/closed/2026-10-09-router-rebuilt-on-every-user-doc-change.md` (P1, fixed) — each photo add rewrites the user doc and resets navigation
- `docs/bugs/closed/2026-10-09-profile-photos-uploaded-unresized.md` (P2, inferred)

---

### Feature: Meal creation

Status: active
Related PRD entry: `docs/PRD.md § Meals`

**Golden path:**
- [ ] From home, "Create a meal" → restaurant search (list) → search filters the Paris list → tap a restaurant → details.
- [ ] Details: pick a future date/time, optional note, women-only toggle → "Create meal" → a `meals/{id}` doc is written (hostId = me, status `open`, geohash set) → back to home with confirmation.
- [ ] Women-only toggle persists on the meal doc.
- [ ] Host can read/update/delete only their own meals (rules); a non-host cannot (rules-tested manually once discovery opens read in Plan 5).

**Edge cases (specific to this feature):**
- [ ] geohash computed at creation from the restaurant lat/lng (unit-tested against the canonical reference).
- [ ] Create-meal error (write fails) renders an error, does NOT fire `meal_created` (analytics only on success).
- [ ] Deep-link/restart on `/meals/new/details` with no restaurant → falls back to search (no crash).
- [ ] `seats` fixed at 1 (1:1); date/time is future-only.

**Shipped / deferred:** real Places search is live via the `searchRestaurants` callable (the fake 20-restaurant list remains only as a test double); an embedded map preview is post-MVP (the "Open in Maps" link-out shipped).

**Known issues:**
- `docs/bugs/closed/2026-10-09-awaited-writes-block-ui-offline.md` (P2) — Create meal spins until the server acks
- `docs/bugs/closed/2026-10-09-discovery-feed-stale-and-unbounded.md` (P2) — no way to cancel/expire a meal
- `docs/bugs/closed/2026-10-12-one-malformed-meal-breaks-discover-for-everyone.md` (**P1**, open) — the `meals` rule accepts `restaurant: {}`
- `docs/bugs/2026-10-12-minor-findings-second-sweep.md` (P3) — restaurant search field/retry/billing nits

---

### Feature: Discovery

Status: active
Related PRD entry: `docs/PRD.md § Discovery`

**Golden path:**
- [ ] A fully-onboarded user lands on the **discovery feed** at `/` (replaces the placeholder home).
- [ ] The feed lists open, future meals near the user (device GPS via geolocator; **Paris-center fallback** if location denied), sorted by distance; each card shows restaurant, time, distance, host name/photo.
- [ ] Tap a meal → detail (restaurant + host profile + time/note/women-only); "Request to join" is present but **disabled** (Plan 6).
- [ ] Pull-to-refresh re-reads location + refreshes the feed. "Create a meal" FAB works.
- [ ] Seed script (`scripts/seed`, firebase-admin → **stage** DB) populates ~12 users + ~18 meals so the feed has content. `npm run wipe` cleans them.

**Edge cases (specific to this feature):**
- [ ] My own meals are excluded from the feed; past meals excluded.
- [ ] **Women-only meals hidden** from non-women viewers; visible (with badge) to women.
- [ ] Location denied/error → Paris center; feed still works.
- [ ] geohash prefix query (precision 4 ~Paris cell) + client distance sort; any signed-in user can READ meals + host profiles (rules opened; writes still owner-only).
- [ ] Empty state ("No meals nearby yet") when nothing matches.

**Deferred (post-MVP, see PRD):** map view of the feed.

**Known issues:**
- `docs/bugs/closed/2026-10-09-discovery-feed-stale-and-unbounded.md` (P2)
- `docs/bugs/closed/2026-10-09-location-fix-has-no-timeout.md` (P2)
- `docs/bugs/closed/2026-10-12-one-malformed-meal-breaks-discover-for-everyone.md` (**P1**, open)
- `docs/bugs/closed/2026-10-12-feed-is-empty-for-any-device-outside-paris.md` (P2, open) — store-review risk
- `docs/bugs/2026-10-12-seed-script-writes-legacy-users-shape.md` (P2, open) — the seed golden-path line above is currently untrue for host names/photos

---

### Feature: Requests & match

Status: active
Related PRD entry: `docs/PRD.md § Matching`

**Golden path:**
- [ ] From meal detail, a signed-in non-host guest taps "Request to join" → a `requests/{mealId_guestId}` doc is written (`status: pending`) → the pinned action bar's button becomes a disabled "Requested" with the status line "Waiting for the host to reply."
- [ ] The host opens the discovery app-bar inbox (`/requests`) → sees the pending request as a tile (guest photo/name/derived age) with **Approve** and **Deny** actions, and under the guest's label the meal the request is for (restaurant on its own line, ellipsized; date/time on the next, in the viewer's local time), with Deny/Approve on a second row. While the meal is loading, errored or missing the line is simply absent and the tile works as before. (Meal line: widget-tested in `request_inbox_tile_test.dart` groups "meal line"; E2E in `inbox_feedback_test.dart`.)
- [ ] Host taps **Approve** → a client transaction locks the meal (`status` leaves `open`), creates a `matches/{mealId}` doc, marks this request `approved`, and denies every other pending request on the same meal ("sibling" denials) → the approved guest's action bar flips to an enabled "Open chat" button with the status line "You're matched. Say hi!"; denied guests see a disabled "Not selected" with "The host chose someone else."
- [ ] A second guest who requests the now-locked meal is rejected (request creation blocked once the meal is no longer `open`).
- [ ] `matches/{mealId}` is the hand-off doc Plan 7 (chat) reads from.

**Edge cases (specific to this feature):**
- [ ] A host cannot request their own meal — the action bar shows a disabled "This is your meal" button with "See requests in the Requests tab." instead of a request button, no request stream touched.
- [ ] Requesting a non-`open` meal (already matched/cancelled/completed) is rejected client + rules side.
- [ ] Denied requests are terminal — no re-request, no state flip back to pending.
- [ ] Approving a request whose meal raced shut (approved by a concurrent transaction first) throws `MealNoLongerOpenException`; the inbox surfaces a SnackBar ("This meal is no longer open.") instead of crashing, and does not deny/approve anything. (Widget-tested, both with the tile still mounted and removed mid-flight; not E2E.)
- [ ] Past meal: when the meal's time is before now, the tile shows a "Meal time has passed" chip under the meal line, **Approve is disabled** and **Deny stays enabled** so the host can clear the request; the request is marked, not hidden. A future meal shows no chip and Approve is enabled. (Widget-tested in the "past meal" group; E2E scenario "past-meal request is marked, Approve disabled, Deny clears it". The check uses the device clock at build time: the chip appears only on the next rebuild if the meal time passes while the inbox is open, and a request right at the server/device clock boundary can still fail with the generic message below.)
- [ ] Every Approve/Deny outcome gives SnackBar feedback (texts from `inbox_action_message.dart`; the mapping is unit-tested in `inbox_action_message_test.dart`, the tile wiring is widget-tested in the "outcome feedback" group):
  - Approve success: "Approved. You can chat now." with a **Chat** action that opens `/chats/{mealId}` (widget test checks the navigation; E2E scenario "approve shows feedback and its Chat action opens the chat" taps it and sees the chat composer).
  - Approve, `MealNoLongerOpenException`: "This meal is no longer open." (widget-tested, see above).
  - Approve, any other error: "Couldn't approve this request. It may already have been handled." (widget-tested only; not E2E).
  - Deny success: "Request denied." (widget-tested; E2E in the past-meal scenario, which also checks the request becomes `denied` and the tile disappears).
  - Deny, any error: "Couldn't deny this request. It may already have been handled." (widget-tested only; not E2E).
  - The generic wording is deliberate: the app layer cannot tell already-decided and past-meal failures (or a failed offline approve) apart without leaking Firebase types, and all mean nothing changed. Offline differs per action: Approve is a transaction and errors (generic message); Deny is a queued write that never errors, the tile vanishes optimistically and "Request denied." appears only after reconnect.
  - The Approve snackbar (it has a Chat action) is non-persistent: it auto-dismisses after ~6 s (~8 s with accessible navigation), has a close icon, and a new outcome replaces it (widget-tested).
  - A disabled Approve on a past meal carries a tooltip and a semantics hint ("Meal time has passed").
  - Unmounting the tile mid-flight (approve or deny) neither throws nor loses the snackbar (widget-tested).
- [ ] Discovery app-bar inbox badge (`pendingRequestCountProvider`) shows the live pending count and hides itself at 0 (unit-tested in `discovery_inbox_badge_test.dart`).
- [ ] Women-only meals are unaffected by the request/match flow — the existing discovery-time gender filter is untouched; requests/matches carry no gender logic of their own. (Rules sweep 2026-10-09: a man cannot request a women-only meal; women-only meals are still *readable* by any signed-in user, see the rules-hardening bug.)
- [ ] `join_requested` / `request_approved` / `request_denied` / `match_created` all fire from the controller layer (`create_request_controller.dart`, `inbox_action_controller.dart`), never inline in widgets.

**Manual rules note:**
- [ ] Firestore rules (`firebase/firestore.rules`) restrict `requests/{id}` writes to the guest (create, pending only) and the host (status transition pending→approved/denied only); `matches/{mealId}` is host/guest-readable, write-restricted to the approve transaction. Verify via Rules Playground or emulator — a non-host cannot approve/deny another host's request, and a non-participant cannot read a match doc.

**Known issues:**
- `docs/bugs/closed/2026-10-09-awaited-writes-block-ui-offline.md` (P2) — Request to join spins offline (re-verified fixed 2026-10-12)
- `docs/bugs/2026-10-12-requests-rule-lets-a-guest-break-the-hosts-inbox.md` (P2, open)

---

### Feature: Chat

Status: active
Related PRD entry: `docs/PRD.md § Chat`

**Golden path:**
- [ ] Host approves a request → guest's meal-detail "Open chat" button (key `meal_detail_matched_banner`) → pushes `/chats/{mealId}` straight into the new chat.
- [ ] Chats tab (`/chats`) lists every match as a row (other participant photo/name, last-message preview, relative time); tapping a row opens `/chats/:matchId`.
- [ ] Chat screen: app bar shows the other participant's name/photo (looked up via `chatListProvider`); sending a message via the composer writes to `matches/{matchId}/messages` and appears immediately (mine, right-aligned).
- [ ] The other participant, viewing the same match in a second session, sees the message arrive in realtime (left-aligned) and the sender's bubble flips to "Seen" once the other participant opens the chat (`reads/{uid}.lastReadAt` compared to the message's `createdAt`).
- [ ] Bottom-nav tab switching preserves each tab's navigation stack (Chats list ↔ chat detail) independently of Discover/Requests/Profile (`StatefulShellRoute`, unit-tested in `app_shell_test.dart`).

**Edge cases (specific to this feature):**
- [ ] A signed-in user who is **not** a participant on a match cannot read its `messages`/`reads` subcollections — verify via Rules Playground or emulator (`firebase/firestore.rules`).
- [ ] Blank/whitespace-only text is blocked client-side (`ChatController.send` no-ops on blank; composer's send button stays disabled while the field is empty) and rejected repository-side (`sendMessage` throws on 0/`>2000` chars).
- [ ] Chats-tab unread dot: shown when the last message on a match is inbound (`senderId != me`); hidden once I've sent the most recent message. (Simplified heuristic — a full compare against my own `reads` doc is deferred, not required for MVP.)
- [ ] Empty states: no matches yet → "No chats yet" / "Match on a meal to start talking." with a "Find a meal" button; a match with no messages yet → "Say hi 👋".
- [ ] `chat_opened` fires once per chat-screen open (guarded in `initState`, not on every rebuild); `message_sent` fires only after a successful write.
- [ ] Route guard: `/chats/:matchId` with a missing/blank `matchId` falls back to the chat list instead of crashing on a null path param.

**Manual rules note:**
- [ ] `matches/{matchId}/messages/{id}` and `matches/{matchId}/reads/{uid}` are readable/writable only by `match.hostId`/`match.guestId` (participants array) — verify a third user is denied both read and write via emulator.

**Known issues:**
- `docs/bugs/closed/2026-10-09-chat-keyboard-squeezes-message-list.md` (P2)
- `docs/bugs/closed/2026-10-09-awaited-writes-block-ui-offline.md` (P2) — composer stuck on a spinner offline
- `docs/bugs/closed/2026-10-09-providers-survive-sign-out.md` (P2) — one full-history listener per chat row
- `docs/bugs/closed/2026-10-12-chat-of-cancelled-match-shows-generic-error-and-reports-fatal.md` (P2, fixed)
- `docs/bugs/closed/2026-10-12-push-tap-strands-user-in-chat-without-back.md` (**P1**, open)

---

### Feature: Safety & moderation

Status: active
Related PRD entry: `docs/PRD.md § Safety`

**Golden path:**
- [ ] Block a user from meal detail or chat → a `blocks/{a}_{b}` doc created with pair array → blocker's perspective: user vanishes from discovery feed and they cannot appear in the blocker's inbox/chat (rules enforce both directions).
- [ ] Blocked user attempts to request a meal from the blocker → `noBlockBetween` rule rejects (`create_request_controller` displays "User not available").
- [ ] Blocked user sends a chat message → `noBlockBetween` rule rejects in `matches/{matchId}/messages` create.
- [ ] Report a user/meal/message → a `reports/{id}` doc is written (create-only, contains reporterId, targetType, targetId, reason) → Firestore records the report (no immediate action on client).
- [ ] Non-woman user requests a women-only meal → the action bar shows a disabled "Women only" button with "Only women can join this meal." (client guard) and the rule rejects the create if the guard fails.
- [ ] Woman user requests a women-only meal → request succeeds (rules allow).
- [ ] Account deletion: tap Settings → Delete account → one confirmation dialog (no re-authentication, no success dialog) → `deleteAccount` callable is invoked → automatic sign-out → user + profile docs, meals, requests, matches, ratings, photos and the Auth account are purged by the Cloud Function. Matched meals are released first (see "Account deletion with a matched meal"). Reports the user filed or that target them are retained for safety.

**Edge cases (specific to this feature):**
- [ ] Blocking is bidirectional: if A blocks B, both A→B and B→A interactions are denied (rules verify both `blocks/{a}_{b}` and `blocks/{b}_{a}` do not exist).
- [ ] Reports are create-only (no read/update/delete via client); Firestore rules reject any attempt.
- [ ] Women-only meal rule enforces gender field read: a malformed user (missing gender) is treated as non-woman.
- [ ] Block deletion: blocker can unblock via `blocks/{blockId}` delete (blockerUid check); blocked user cannot (rule rejects).
- [ ] Deletion is cascading: deleteAccount callable deletes the user doc, all user-owned meals, all requests as guest, all matches as a participant, FCM tokens, the public profile doc, ratings in both directions, and profile pictures (Storage prefix `{env}/users/{uid}/`). Reports are intentionally retained.
- [ ] After account deletion, all references to the deleted user's profile (name, photo) in persisted matches/messages are stale (no retroactive cleanup — acceptable for MVP).

**Manual emulator verification (off-platform):**
- [ ] Block rules work in both directions (use Firestore Emulator to inspect blocks/{blockId} and verify the pair constraint).
- [ ] Report create-only verified via Firestore rules or emulator (client cannot read/update a report).
- [ ] Women-only rule verified in Rules Playground: a user with `gender: 'woman'` passes; no gender or `gender: 'man'` fails.
- [ ] Deletion cascade verified: delete a user → ensure their meals, requests, matches, fcmTokens are all gone (emulator Firestore inspection).

**Deferred (post-MVP):**
- Automated content moderation (Cloud Function listening to `reports` for spam/abuse, flagging/deleting content).
- Silent-block mirror: Function writes to a parallel collection for analytics without user awareness.
- Live account deletion via UI (requires **Blaze plan**; current callable requires manual backend trigger or custom Cloud Function for email verification).

**Known issues:**
- Stale text above: Settings -> Delete account (single confirm dialog, no re-auth) ships and the callable also deletes the Storage prefix; see `docs/bugs/closed/2026-10-09-docs-contradict-code.md`.
- `docs/bugs/closed/2026-10-09-deleted-guest-strands-hosts-matched-meal.md` (P2)
- `docs/bugs/closed/2026-10-09-firestore-rules-hardening-gaps.md` (P3)
- `docs/bugs/2026-10-12-report-and-block-spin-forever-offline.md` (P2, open)
- `docs/bugs/2026-10-12-minor-findings-second-sweep.md` (P3) — stale `docs-contradict-code` remnants, local cache not cleared on sign-out
- Block detection is possible via direct Firestore inspection (silent-block mirror not yet implemented).
- Store-UGC risk (decided, not a bug): no automated moderation and no operator workflow for `reports` (create-only, nobody reads them); Apple 1.2 / Play UGC reviewers may ask for one.

---

### Feature: Push notifications

Status: active
Related PRD entry: `docs/PRD.md § Push notifications`

**Golden path (emulator/device):**
- [ ] A guest sends a request to join a meal → the host's device receives a push notification; tapping it opens `/requests`.
- [ ] A participant sends a chat message → the other participant's device receives a push notification; tapping it opens that chat (`/chats/:matchId`).
- [ ] The host approves a request → the approved guest's device receives a push notification.

**Edge cases (specific to this feature):**
- [ ] A recipient with no registered `fcmTokens` entry is a silent no-op — the trigger completes without error, no push attempted.
- [ ] An invalid/expired token (FCM reports `messaging/registration-token-not-registered` or similar) is pruned from `users/{uid}/fcmTokens` by the trigger, not just skipped.
- [ ] `users/{uid}/fcmTokens/{token}` is readable/writable only by the owning user (Firestore rules) — verify a non-owner is denied via Rules Playground or emulator.
- [ ] Cold-start tap on a push (app not running) deep-links correctly without crashing on a disposed/uninitialized router state.
- [ ] Foreground message while the relevant screen is already open shows an in-app banner, not a duplicate system notification.
- [ ] Triggers fire correctly against **both** Firestore databases (`(default)`=prod, `stage`=stage) — each is registered separately in `index.ts`.

**Pending native config (blocks live delivery):**
- Live end-to-end delivery is unverified pending **Blaze plan** upgrade (Cloud Functions can't deploy on Spark), an **APNs auth key** (iOS push), and registering the **Android SHA-256** fingerprint — all user homework, tracked in `docs/CICD.md` / build-state memory. Until then, the Functions triggers are unit/integration-tested in isolation (`firebase/functions/test/`) but not exercised against a real device.

**Known issues:**
- `docs/bugs/2026-10-09-minor-polish-and-ci-gaps.md` (P3) — foreground banner while the chat is open, token-refresh error handling
- `docs/bugs/closed/2026-10-12-push-tap-strands-user-in-chat-without-back.md` (**P1**, open) — tapped chat pushes use `go`, not `push`; the shell and this listener are disposed
- Route mapper covers every type the server sends (`request`, `request_update`, `message`, `rate`, `meal_reminder`); guarded by `test/features/notifications/data/push_type_contract_test.dart`.

---

### Feature: Post-meal & ratings

Status: active
Related PRD entry: `docs/PRD.md § Ratings`

**Golden path:**
- [ ] After the meal `dateTime` has passed, the post-meal card ("How was your meal?") appears in the match's chat.
- [ ] Tap the card → rating sheet appears with star picker (1–5), show-up toggle, and optional comment field.
- [ ] Select stars + toggle show-up (true/false) + optionally type a comment (≤200 chars) → "Submit" writes a `ratings/{matchId}_{raterUid}` doc.
- [ ] Both participants receive a post-meal "How was it?" push (type `'rate'`) from the hourly `postMealReminder` once the meal's start time has passed (up to an hour after it began), before anyone has rated. Tapping it opens the match chat with the rating card.
- [ ] After rating, the target user's profile card shows a rating badge (⭐ count displayed, e.g. "⭐ 4.5 (12)").
- [ ] The target user's `AppUser.ratingAvg` and `ratingCount` are updated by the `onRatingCreated` aggregate Function in realtime; their profile screen reflects the new aggregate.

**Edge cases (specific to this feature):**
- [ ] Only meal participants can rate — a non-participant attempting to write a rating is rejected by rules.
- [ ] A user cannot rate themselves — the rule rejects if `raterUid == targetUid`.
- [ ] Star count must be 1–5 inclusive — submit disabled if outside range (client); rule rejects otherwise.
- [ ] Comment is optional, but if present must be ≤200 chars (both client validation + rule check).
- [ ] One rating per match per rater — the doc id is `{matchId}_{raterUid}` and ratings are create-only: a second attempt is rejected by the rules (no overwrite).
- [ ] `AppUser.ratingCount` and `ratingAvg` are write-protected: client cannot write them directly (Firestore rules validate `ratingSum/ratingCount/ratingAvg` unchanged in user updates).
- [ ] Scheduled post-meal push (`postMealReminder`, hourly Pub/Sub) is deduplicated via the `postMealNotified` flag; once sent, a meal does not re-notify its participants.
- [ ] `postMealReminder` marks a matched meal `completed` at its first hourly run after the meal time, whether or not anyone has rated.

**Manual emulator/Blaze verification:**
- [ ] Firestore rules reject a rating where `raterUid == targetUid` (write forbidden).
- [ ] Firestore rules reject a rating from a non-participant (the match doc must exist and the rater must be hostId or guestId).
- [ ] `onRatingCreated` trigger updates the target's `ratingCount` and `ratingAvg` (requires Blaze; emulator trigger does not execute remotely, so inspection of the updated user doc confirms the Function logic).
- [ ] Scheduled `postMealReminder` function runs hourly and sends a notification to non-notified participants (requires Blaze + Cloud Scheduler; emulator cannot run scheduled triggers).

**Known issues:**
- `docs/bugs/2026-10-09-minor-polish-and-ci-gaps.md` (P3) — the rate prompt fires at meal start
- Live aggregate updates + scheduled push notification delivery require the project to be on **Blaze** plan; if still on Spark, Functions deploy fails and rating aggregates/pushes are non-functional.

---

### Feature: Open in Maps (meal detail)

Status: active
Related PRD entry: `docs/PRD.md § Feature: Open restaurant in Maps (meal detail)` · design: `docs/DESIGN.md § Meal detail — "Open in Maps" action` · analytics: `directions_opened`
Automated: `test/features/meal/application/maps_launcher_provider_test.dart`, `maps_launcher_uris_edge_test.dart`, `test/features/meal/presentation/meal_detail_open_in_maps_test.dart`, `meal_detail_open_in_maps_edge_test.dart`

**Golden path:**
- [ ] Meal detail for a restaurant with real coordinates shows "Open in Maps" (outlined, map-pin icon, left-aligned, intrinsic width) inside the restaurant card. *(Automated.)*
- [ ] **iOS (real device + Simulator):** tap opens Apple Maps at the restaurant with the name as the pin label; Maps is foregrounded (no in-app browser, no Safari bounce). Verify that `ll` + `q` drops a pin at the exact lat/lng labelled with the name, rather than running a name search that snaps to a different nearby POI.
- [ ] **Android (real device + Emulator with Google Play):** tap opens Google Maps at the pin with the name as the label. With a second geo handler installed (e.g. Waze), the system chooser appears and both work.
- [ ] Returning to Convyve (back / app switcher) lands on the unchanged meal detail; the button is immediately usable again.
- [ ] `directions_opened` fires once per tap, no properties (verified in code via log-sink tests). **Still to do manually:** see it in the Firebase Analytics DebugView (not verifiable without a device).

**Edge cases (specific to this feature):**
- [ ] Coordinates `0,0`, out of range, or NaN: button hidden, address still shown. *(Automated.)*
- [ ] Android 11+ package visibility: `launchUrl` (not `canLaunchUrl`) is used, so no `<queries>` entry is needed; confirm on an Android 11+/14 device and on an emulator image WITHOUT Google Maps that `geo:` failing falls back to the https Google Maps URL (browser) and, with no handler at all, shows "Couldn't open Maps". *(URI order, false-vs-throw fallback automated via faked method channel.)*
- [ ] iOS: no `LSApplicationQueriesSchemes` is required for https launches (only `canLaunchUrl` needs it). Confirm launch works from a release/TestFlight build with the Info.plist as committed.
- [ ] Restaurant names with `&`, `#`, `%`, `+`, `=`, `?`, quotes, emoji, CJK, Cyrillic, Arabic, parentheses: apple `q` and geo label round-trip exactly (parentheses become spaces in the geo label). *(Automated.)* Manually spot-check one non-Latin and one `&` venue on each platform that the maps app shows the correct label.
- [ ] 1000+ character restaurant name: URI stays valid; card does not overflow at 1.5x. *(Automated.)* Check whether the maps app truncates/refuses a very long `q` label on-device.
- [ ] Viewer variants: guest (no request / pending / approved / denied / request-state loading / error), host viewing own meal, women-only meal as woman and non-woman viewer: button present and working in all. *(Automated.)*
- [ ] Double-tap / rapid tap: exactly one launch and one `directions_opened`; guard releases after success, `false`, and a throwing launcher. *(Automated.)*
- [ ] Failed launch (`false`): snackbar "Couldn't open Maps", button stays enabled, event already counted (intent). *(Automated.)*
- [ ] Analytics sink failure never blocks the hand-off. *(Automated.)*
- [ ] Leave the screen while a launch is in flight: no snackbar on an unmounted screen. *(Automated.)* Leave the screen while the `track()` await is in flight: fixed, see `docs/bugs/closed/2026-10-09-open-in-maps-ref-after-dispose.md`.
- [ ] Offline / airplane mode: button still launches the maps app; Convyve shows no connectivity error. Maps app owns its offline state. *(Manual.)*
- [ ] Background app mid-launch / kill Maps and return: Convyve state unchanged, no crash. *(Manual.)*
- [ ] Accessibility: TalkBack/VoiceOver announce one button "Open <name> in Maps" (no duplicate "Open in Maps" announcement); semantics tap action launches once; target >= 48dp at 2.0x. *(Semantics automated; screen-reader pass manual.)*
- [ ] RTL (Arabic/Hebrew locale): button aligns to the start (right) edge. *(Automated via `Directionality`; confirm with a real RTL locale.)*
- [ ] Dark + light parity at 1.5x/2.0x text, 320dp wide. *(Automated, light 2.0x and dark 1.5x/2.0x.)*
- [ ] Coordinate precision: very small values (|lat| or |lng| < 1e-6) would stringify in scientific notation (`1e-7`). Not a real restaurant case; noted, not guarded.

**Known issues:**
- `docs/bugs/closed/2026-10-09-open-in-maps-ref-after-dispose.md` (P2, fixed; closed in the 2026-10-09 sweep: regression test un-skipped and green)
- `docs/bugs/closed/2026-10-09-meal-detail-women-only-badge-overflow-2x.md` (P3, pre-existing, same card; fixed; closed in the 2026-10-09 sweep)

---

### Feature: Can't make it (cancel / withdraw a matched meal)

**Automated:** `firebase/functions/test/cancel_meal.test.ts` (who may cancel, matched + future only, host vs guest outcome, push wording); `leave_match_action_test.dart` (visibility, host/guest dialogs, keep, failure snackbar, 2.0x text); `leave_match_controller_test.dart` (success tracks `meal_cancelled` with the role, failure doesn't); `match_repository_impl_test.dart` (callable payload, error mapping). `applyCancel` checked against the Firestore emulator: host cancel -> `cancelled` + chat/messages gone; guest withdraw -> `open`, guest cleared, flags cleared, request + chat removed; second call, stranger, past meal and missing meal are rejected.

**Manual on stage (two accounts, deployed `cancelMatchedMeal`, App Check token registered):**
- [ ] Host: matched future meal -> chat -> "Can't make it" -> confirm: snackbar "Meal cancelled.", lands on Chats, the chat is gone; the guest gets "Meal cancelled - The host cancelled this meal" (tap opens Discover).
- [ ] Guest: same -> "You've withdrawn."; the host gets "Your match withdrew" and the meal is in Discover again for another user; when someone else is approved the reminders start fresh.
- [ ] The action is absent after the meal time (and the chat is only reachable for matched meals).
- [ ] Airplane mode: confirm -> "Couldn't cancel. Check your connection and try again."; nothing changed.
- [ ] `meal_cancelled` (role host/guest) appears in DebugView.

**Re-verified 2026-10-12 (Firestore emulator, compiled functions: `firebase/functions/test-emulator/state_machine.test.cjs`; rules: `client_write_shapes.rules.test.cjs`):** guest withdraw reopens the meal, clears the three scheduler flags, removes request + chat, the same guest can re-request and be re-approved; host cancel ends in `cancelled` and is never reminded or completed; concurrent cancel from both sides lets exactly one win; after the meal time the cancel is refused and `postMealReminder` completes the meal once. Fixed: other person's open chat now shows "no longer available" (`docs/bugs/closed/2026-10-12-chat-of-cancelled-match-shows-generic-error-and-reports-fatal.md`). Open: a crash between the transaction and the chat deletion blocks re-matching (`docs/bugs/2026-10-12-cancel-meal-can-leave-a-stale-match-that-blocks-rematching.md`), denied requesters cannot return (P3, minor findings).

---

### Feature: Rules hardening (reports, messages, ratings, storage)

**Automated:** `firebase/rules-test/hardening.rules.test.cjs` (reports: key whitelist + size caps; messages: server `createdAt`, no extra keys; ratings: exact keys, no client `aggregated`, server `createdAt`). Run: `cd firebase/rules-test && npm install && npm test` (also a CI job).

**Manual (stage, after deploying rules + functions):**
- [ ] Send a chat message, file a report, submit a rating: all still work from the app (the rules now expect exactly the keys/`serverTimestamp()` the app writes).
- [ ] Upload a profile photo (Storage rule now requires env `stage|prod`).
- [ ] Delete an account: still works with App Check on (`deleteAccount` now enforces it); register the debug token on dev devices first.

**Re-verified 2026-10-12:** every repository write shape (message, rating with/without comment, report, meal, request, approve transaction, deny, sibling denies, reads, block/unblock, fcm token, age gate batch, profile batch, age self-heal) is accepted by the rules emulator and its keys are checked against the rules' `hasOnly` lists on every `flutter test` run (`test/core/firebase/rules_write_shape_contract_test.dart`). Gaps found: `meals.restaurant`, `requests` keys/`createdAt`, `profiles` field types, `reads`/`blocks` keys (see the two P1/P2 bug files above and `docs/bugs/2026-10-12-minor-findings-second-sweep.md`). Storage rules: reviewed, still NOT VERIFIED HERE (no emulator test).

---

### Feature: Photo size and avatar decoding

**Automated:** `test/core/design/avatar_image_test.dart` (decode width = radius x 2 x DPR, no upscaling; a failing photo raises no framework error).

**Manual on a device:**
- [ ] Add a photo from a 48-200 MP camera roll image: it uploads (no "profile error"); the Storage object is well under 8 MB (~1080 px).
- [ ] Discover / Chats / inbox with ~20 hosts' photos scrolls smoothly on a mid-tier Android phone (DevTools memory stays flat).
- [ ] Remove a photo then view the old profile elsewhere: the avatar shows the person icon, and Crashlytics gets no fatal image error.

---

### Feature: Account deletion with a matched meal

**Automated:** `firebase/functions/test/matched_meals.test.ts` (future meal reopens + flags cleared; past meal cancelled; host-leaving notify rule; push payloads); `push_route_mapper_test.dart` and `push_type_contract_test.dart` (new push types have a client route). Behaviour of `releaseMatchedMeals` checked against the Firestore emulator (reopen, cancel, untouched others).

**Manual on stage (two accounts, deployed functions):**
- [ ] Host posts a meal, guest joins and is approved. Guest deletes the account: the host gets "Your match left Convyve", the meal is listed in Discover again (as another user) and gets fresh reminders when matched again; no reminder fires for the old match.
- [ ] Same, but the meal time has passed: the host's meal is cancelled and no rating prompt arrives.
- [ ] Host deletes the account with a matched future meal: the guest gets "Meal cancelled"; tapping it opens Discover.
- [ ] Deletion still completes if a push fails (no device token).

---

### Feature: Location fix never hangs

**Automated:** `test/core/location/location_service_timeout_edge_test.dart` (denied, error, never-arriving fix -> Paris within the timeout, last known position preferred, hanging last-known lookup, in-time fix).

**Manual on a device:**
- [ ] Location permission granted but no fix (airplane mode / indoors / emulator without a mock location): Discover leaves the spinner within ~10 s and shows the Paris feed.
- [ ] Pull to refresh in that state does not hang again.
- [ ] Permission denied: Paris feed immediately (unchanged). Granting later and pulling to refresh uses the real position.

---

### Feature: Sign-out drops per-user state

**Automated:** `test/core/auth_transition_state_test.dart` (waits while auth resolves; no Firestore read when signed out; an unwatched profile closes its listener; sign-out then sign-in re-subscribes); `chat_repository_impl_test.dart` (`watchLastMessage` = newest only); chat list tests use `lastMessageProvider`.

**Manual on a device:**
- [ ] Sign in as A, open chats and a profile, sign out, sign in as B: no data or error from A's session appears (no stale profile, thread or "permission denied").
- [ ] Chats tab with several matches: each row shows the last message; (DevTools/Firestore usage) it does not download every match's full history.
- [ ] Sign out while a chat is open: lands on sign-in, no crash or red error flash.
- Known follow-up: the open chat thread is still unbounded (`limit` + load-more not built).

---

### Feature: Large text sizes

**Automated (real Nunito font, 360x640):** `signin_screen_text_scale_edge_test` (1.0/1.5/2.0x, both themes), `sheets_keyboard_edge_test` (rating + report: keyboard, 1.5x, 2.0x), `age_gate_text_scale_test` (1.5/2.0x, button reachable by scrolling), `chat_screen_edge_test` (keyboard open keeps the thread readable; 1.5x no overflow).

**Manual on a device at the largest system font (Android 2.0x / iOS Larger Accessibility Sizes):**
- [ ] Sign-in: all three buttons readable, labels wrap, nothing clipped.
- [ ] Age gate: scrolls; Continue reachable.
- [ ] Rating / report sheets: open the keyboard, the field and Submit stay reachable (scroll).
- [ ] Chat after the meal time: with the keyboard open the tips and rating card are hidden and the thread is usable; with it closed they show and scroll if tall.

---

### Feature: Offline writes don't block the UI

**Automated:** `test/core/util/queued_write_test.dart` (ack, rejection inside the grace period, pending past it = queued, late error swallowed); `message_composer_offline_edge_test.dart` (composer frees up); `create_meal_controller_test.dart` (never-acknowledged create settles).

**Manual on a device (airplane mode):**
- [ ] Chat: send a message; within ~3 s the field clears and a second message can be sent; both appear in the thread; after reconnecting they deliver once each (no duplicates).
- [ ] Create meal / Request to join / Rate: after ~3 s the screen moves on instead of spinning; after reconnect the meal / request / rating appears server-side (check Firestore) and the host gets the push.
- [ ] A write rejected by the rules while online (e.g. messaging someone who blocked you) still shows the error within 3 s.
- Known trade-off: while offline the success snackbar ("Meal created!") appears even though delivery waits for the network; a rejection that only arrives after reconnect is logged, not shown.

---

### Feature: Discovery feed freshness

**Automated:** `test/features/meal/application/discovery_clock_edge_test.dart` (a meal drops when its start passes with no new snapshot; only started meals drop; unchanged feed doesn't recount `discovery_viewed`); `meal_repository_impl_test.dart` (past meals excluded, soonest-first, capped at 100).

**Manual:**
- [ ] Leave Discover open past a listed meal's start time: it disappears without pulling or reopening.
- [ ] Production data: the `status + dateTime` index is deployed (`firebase/firestore.indexes.json`), the Discover query succeeds (no "requires an index" error).
- [ ] Known follow-up: cancelling a meal — `docs/bugs/closed/2026-10-10-no-way-to-cancel-a-meal.md`.

---

### Feature: Core analytics events (app_opened, signup/signin, identify)

**Automated:** `test/core/analytics/session_tracker_test.dart`, `analytics_listener_test.dart`, `tracking_plan_parity_test.dart` (every registry event is fired somewhere in `lib/`), `auth_repository_impl_test.dart` (method + timestamps mapping).

**Manual on a device with `--dart-define=ANALYTICS_IN_DEV=true`, Firebase Analytics DebugView:**
- [ ] Cold start: `app_opened` (`is_cold_start: true`); background and resume: `app_opened` (`false`).
- [ ] Brand-new account via Google / Apple / phone: one `signup_completed` with the right `method`; user properties `signup_date`, `signup_method`, `app_version`, `platform` appear.
- [ ] Sign out and sign back in with an existing account: one `signin_completed`; no `signup_completed`.
- [ ] Kill and relaunch while signed in: `app_opened` + identify, but no `signin_completed`.
- [ ] After sign-out, new events carry no user id (`reset`).

Re-verified 2026-10-12 (unit): the registry, the plan and the call sites agree and every event is fired from `lib/`; `AnalyticsListener` and `SessionTracker` behave as documented. P3 findings (duplicate `signup_completed` on a relaunch within 2 minutes, `discovery_viewed` re-fires on own-doc changes, provider pick) in `docs/bugs/2026-10-12-minor-findings-second-sweep.md`. DebugView NOT VERIFIED HERE.

---

### Feature: Private vs public profile

**Automated:** `firebase/rules-test/users_profiles.rules.test.cjs` (7 cases, emulator); `test/features/user/data/*` (DTO split, merge, public age self-heal, no dob/gender in the public doc); `firebase/functions/test/profile_split.test.ts` (backfill split).

**Manual (stage, after the rollout in `docs/RELEASE.md` §1.5):**
- [ ] Sign up a new account: age gate -> profile setup works; a second account sees the first one's name/photo/age on a meal and in the request inbox and chat, with no crash.
- [ ] A second account cannot read `users/<other>` or list `profiles` (Rules Playground / emulator).
- [ ] After a rating lands, the aggregate appears on the rated person's profile badge.
- [ ] Delete an account: both `users/{uid}` and `profiles/{uid}` are gone; their meals/ratings behave as before.
- [ ] Existing test accounts show correct names/photos after the backfill (dry-run first).
- [ ] A person with no public profile shows a neutral placeholder, not an error.

**Re-verified 2026-10-12:** owner writes on a legacy `users` doc are denied until the backfill ran (and pass after the Admin-SDK field removal the script performs); an old pre-split app build cannot write public fields or read `users/<other>` (breaks by design); `profiles/<missing>` resolves to not-found. Open: `docs/bugs/2026-10-12-cd-deploys-rules-before-profile-backfill.md` (P2: CD vs the section 1.5 order, rating loss window), `docs/bugs/2026-10-12-seed-script-writes-legacy-users-shape.md` (P2). The backfill itself (`backfill_profiles.js --apply`) NOT VERIFIED HERE (needs Admin credentials); its pure split is unit-tested.

---

### Feature: Meal reminders (T-24h / T-2h)

**Automated:** `firebase/functions/test/reminders.test.ts` (windows, flags, Paris-time formatting across DST, today/tomorrow label, payload content, truncation); `push_route_mapper_test.dart` (tap → `/chats/:mealId`).

**Manual on the `stage` flavor (real device, two accounts, deployed `mealReminderStage`):**
- [ ] Matched meal ~23h ahead: both phones get "Your meal is tomorrow — <restaurant> at HH:mm" within ~15 min; no second copy on later runs.
- [ ] Matched meal ~90 min ahead: both get "Your meal is coming up"; a meal 3h ahead gets nothing yet.
- [ ] Tap the push (app killed / background / foreground): opens the match chat; `push_opened` with `type: meal_reminder` in DebugView.
- [ ] Meal matched with 30 min to go: no "tomorrow" reminder ever sent.
- [ ] Cancelled or unmatched meal inside a window: nothing sent.
- [ ] One participant has no device token / revoked permission: the other still gets it; no function error loop.
- [ ] Meal across the DST change (last Sunday of October): time in the push matches Paris wall-clock.
- [ ] Check the meal doc after: `reminder24hSent` / `reminder2hSent` set.
- [ ] Post-meal "How was it?" push: tap opens the match chat with the rating card at the top.

---

### Feature: Meal reminders — sweep result 2026-10-09

Server side verified against the Firestore emulator for BOTH databases (`(default)` and `stage`) by running the compiled `mealReminder` handler with a stubbed sender: matched meals inside 22–24h and 1–2h get one push per participant (host only when no guest), meals at 3h / 30min / 21h / past / cancelled / open get nothing, flags `reminder24hSent` / `reminder2hSent` are set, a second run sends nothing, a meal with `reminder24hSent` already set still gets the 2h reminder. Client rules: no client can write the reminder flags and they do not affect the approve transaction. Open: `docs/bugs/closed/2026-10-09-deleted-guest-strands-hosts-matched-meal.md` (reminders for a meal whose guest deleted their account). Device items above remain NOT VERIFIED.

**Re-verified 2026-10-12** with the compiled `mealReminder` / `postMealReminder` handlers against the Firestore emulator (`firebase/functions/test-emulator/state_machine.test.cjs`): flags set once, 24h and 2h independent, open/cancelled meals ignored, a withdrawn-then-reopened meal restarts. Race (non-transactional flag write) and duplicate-prompt notes are P3 in `docs/bugs/2026-10-12-minor-findings-second-sweep.md`.

---

## QA sweep log

### 2026-10-09 (develop @ 8cf1b41) — pre-store-submission code-side sweep

Baseline: `flutter test` 477 passed / 3 skipped (the TZ-gated tests, run separately under `TZ=Pacific/Kiritimati`: green); after the additions below 503 passed / 19 skipped (16 bug-linked); `flutter analyze`: 0 errors, 0 warnings (624 infos); functions `npm test` 31/31, `npm run build`, `npm run lint` clean (Node 22.22). Added tests (all green; bug-linked cases are skipped until fixed): `test/core/routing/router_stability_test.dart`, `test/core/auth_transition_state_test.dart`, `test/core/analytics/tracking_plan_parity_test.dart`, `test/core/location/location_service_timeout_edge_test.dart`, `test/features/chat/presentation/chat_screen_edge_test.dart`, `test/features/chat/presentation/widgets/message_composer_offline_edge_test.dart`, `test/features/auth/presentation/signin_screen_text_scale_edge_test.dart`, `test/features/safety/presentation/sheets_keyboard_edge_test.dart`, `test/features/meal/application/discovery_clock_edge_test.dart`, `test/features/notifications/data/push_type_contract_test.dart`, helper `test/helpers/load_app_fonts.dart` (widget tests render the Ahem font unless Nunito is loaded; use it for any layout/overflow test).

Bugs filed: see `docs/bugs/` (2 P1, 9 P2, 3 P3). Everything marked device/emulator in this plan stays NOT VERIFIED until run locally.

### 2026-10-12 (develop @ 979e5f2) - second code-side sweep before store submission

Baseline: `flutter test` 575 passed / 3 skipped (the TZ-gated ones, green under `TZ=Pacific/Kiritimati`); functions `npm test` 52/52, `npm run build`, `npm run lint` clean; rules tests 10/10; `flutter analyze` 0 errors / 0 warnings; `actionlint` 1.7.7 clean on all three workflows. After the additions below: `flutter test` 588 passed / 17 skipped (14 skipped cases are open-bug regression tests, each names its bug file); rules tests 19 passed / 3 skipped (open bugs); emulator state-machine checks 7/7.

Added tests: `firebase/rules-test/client_write_shapes.rules.test.cjs` (every repository write/query shape through the rules emulator, plus the legacy-doc, old-build and cancel/withdraw state-machine paths), `test/core/firebase/rules_write_shape_contract_test.dart` (repository writes vs the rules' `hasOnly` lists, runs in every `flutter test`), `firebase/functions/test-emulator/state_machine.test.cjs` (compiled functions vs the Firestore emulator; run command in the file header, not in CI), `test/core/routing/push_tap_back_stack_edge_test.dart`, `test/core/routing/cold_start_gate_flash_edge_test.dart`, `test/core/a11y/icon_only_controls_semantics_edge_test.dart`, `test/features/chat/presentation/chat_screen_cancelled_match_edge_test.dart`, `test/features/meal/application/discovery_outside_paris_edge_test.dart`, `test/features/meal/data/meal_repository_poison_edge_test.dart`, `test/features/matching/data/request_inbox_poison_edge_test.dart`, `test/features/safety/application/offline_safety_writes_edge_test.dart`. Every skipped case was run un-skipped first and failed for the stated reason, and each file has a passing harness/baseline case so the failure is not a harness artefact.

Bugs filed (all `docs/bugs/2026-10-12-*.md`): 13 files: 2 P1 (`one-malformed-meal-breaks-discover-for-everyone`, `push-tap-strands-user-in-chat-without-back`), 9 P2, 2 P3. Closed bugs re-checked: all 16 hold except two leftovers re-filed as new files (`report-and-block-spin-forever-offline` for `awaited-writes-block-ui-offline`, and the docs remnants in `minor-findings-second-sweep` for `docs-contradict-code`).

Not verifiable here (no device, console or credentials): everything marked NOT VERIFIED HERE above, the real `firebase deploy`, the backfill against real data, App Check enforcement, FCM delivery, DebugView, Storage rules, performance/memory, and the pre-release checklist items that need a signed build.

---

## End-to-end tests (emulator)

The `integration_test/` suite runs the real app, through the real UI, on an iOS
Simulator against the **Firebase Emulator Suite** (Auth, Firestore, Functions,
Storage). It needs no real Firebase project and touches no cloud data.

**What it covers**

- **Security rules enforced** — `firestore.rules` is loaded and enforced by the
  emulator; unauthorized reads/writes are denied (`rules_enforced_test.dart`).
- **Match integrity (`matches` create rule)** — a `matches/{mealId}` doc can
  only be created by the real approve transaction: the same transaction must
  move the request `pending` to `approved` and the meal `open` to `matched`
  with that guest (`matchApprovalValid`, via `getAfter`/`get`). This closes
  fabricated matches that allowed unsolicited chat and ratings. In
  `rules_enforced_test.dart`, group `matches create — approval integrity`:
  the full approve transaction is allowed (case 1); denied are: no request
  (2), request not approved in the same txn (3), meal left open or not
  matched, or matched with another guest (3b, 3b2, 3c), request already
  approved/denied (4a, 4b), meal already matched (5), another host's meal (6),
  `guestId` not the requester (7), inconsistent `participants` or
  `guestId == hostId` (8), doc id, body `mealId` or body `id` that is not the
  meal id (9, 9b, 9c), a block in either direction (10a, 10b), a body
  `hostId` that is not the caller (11), and a payload with a string, missing
  or non-server `createdAt`, or an extra key (12a-12d). Mutation-checked
  (delete the one clause, the matching case fails): `mealId == matchId` (9b),
  `id == matchId` (9c), `mealAfter.status == 'matched'` (3b2),
  `mealAfter.guestId == guestId` (3c), `hostId == request.auth.uid` (11),
  `createdAt == request.time` (12a, 12b, 12d) and the `keys().hasOnly` payload
  clause (12c). NOT given an isolated case, because the host-only
  `requests`/`meals` update rules and the request-id pinning already deny the
  same attacks, so deleting them would not change the outcome:
  `reqBefore.hostId`, `reqBefore.guestId`, `mealBefore.hostId` and
  `guestId != request.auth.uid`. The remaining clauses (pending/open
  pre-states, `reqAfter.status`, `participants`, `noBlockBetween`) are covered
  by cases 2-5, 7, 8 and 10 but were not individually mutation-checked.
  Post-match E2E seeds (chat, rating, and the pre-existing rules cases that
  need a match) write the `matches` doc through `adminSetDoc` (emulator admin
  REST, rules bypass by design); the real approve path stays covered by
  `request_match_test.dart` (UI) and the allowed-transaction case above.
- **Meal, request and rating integrity** — three rule areas in
  `firestore.rules`. `meals`: `hostId`, `dateTime`, `restaurant`, `womenOnly`
  and `geohash` are immutable; a create must be `open`, guest-less (absent or
  `null`, which is what `createMeal` writes), in the future, and carry exactly
  the keys and types `createMeal` writes (key whitelist, `restaurant` map,
  `womenOnly` bool, `seats` int, `note` null/string up to 200 characters,
  `createdAt == request.time`); the only
  update is `open` to `matched` with a guest while the meal is still in the
  future, tied in the same transaction to
  a genuine `pending` to `approved` request from that guest (`get`/`getAfter`)
  and to the `matches/{mealId}` doc being created (`existsAfter`); no client
  delete (delete + recreate at the same id would keep requests attached to a
  swapped meal; Admin SDK paths such as account deletion bypass rules).
  `requests`: an update requires the stored status to be `pending`, so a
  request is decided once; `approved` is only admitted when the same
  transaction leaves the meal `matched` with that guest and creates the match
  (`requestApprovalLinked`), while `denied` stays a bare write; a create
  requires the meal to be still in the future. `ratings`: the create requires the meal's
  `dateTime <= request.time`. In `rules_enforced_test.dart`, groups
  `meals — integrity`, `requests update — decided once` and
  `ratings create — the meal has happened`:
  - Allowed: `createMeal` (the real repository call, plus the same key set by
    hand, a create with no `guestId` key and a 200-character note; new `MealDto`
    field ⇒ update the meals create whitelist, A1 is the guard), the real
    approve transaction (meal + request + match), a request decided `pending`
    to `denied` (the app deny and the post-commit sibling denies), a request
    `approved` once the meal is matched with that guest and the match exists
    (R1d), a rating on a meal in the past.
  - Denied (meals): update of `hostId`, `dateTime`, `restaurant` or
    `womenOnly`, bare or alongside a valid approve; `matched` with the
    request left pending, with no request doc, with an already approved or
    denied request, or with a request of another guest; a `status` other than
    `matched`; a null `guestId`; an already matched meal; a non-host; a forged
    host approving his own forged request to flip someone else's meal; the
    flip without the `matches` doc; approving a request on a meal that has
    already passed (D10, admin-seeded past `open` meal); create already
    `matched`, with a `guestId`, or in the past; create with an extra key
    (C4), a non-map `restaurant` (C5), a non-bool `womenOnly` (C6), a non-int
    `seats` (C7), a note over 200 characters (C8) or a non-string note (C8b),
    or a client-set `createdAt` (C9); delete of an open meal (and delete +
    recreate) or a matched meal.
  - Denied (requests): approved to denied, denied to approved, and a
    same-status rewrite of a decided request; a bare `approved` write with no
    meal flip and no match (R1b); `approved` while the meal is still open
    (R1e), matched with someone else (R1f) or matched with no match doc (R1g),
    each admin-seeded so it isolates one conjunct; a request on a meal that
    has already passed (D11).
  - Denied (ratings): a rating on a future meal, and on a match with no meal
    doc.
  - Mutation-checked (delete the one clause, an isolating case fails): the
    meals update `affectedKeys().hasOnly(['status', 'guestId'])`, pre-status
    `open`, post-status `matched`, `resource.data.hostId == request.auth.uid`
    (forged-host case) and `existsAfter(matches)`; the link's request
    `pending` (D4a), request `guestId` and `getAfter` `approved` clauses; the
    create `open`, guest-less and future clauses; delete `false` (against
    `host && open` and `host only`); the `requests` `pending` guard (R2-R5:
    R3/R4 start from a linked meal state so the `approved` linkage cannot deny
    them); the ratings meal-date gate; the meals update's
    `resource.data.dateTime > request.time` (D10); the requests create's meal
    `dateTime > request.time` (D11); each `requestApprovalLinked` conjunct
    (`mealAfter.status` R1e, `mealAfter.guestId` R1f, `existsAfter(matches)`
    R1g) and the whole `approved` branch (R1b, R1e-R1g all fail without it);
    the create `keys().hasOnly` whitelist (C4), `restaurant is map` (C5),
    `womenOnly is bool` (C6), `seats is int` (C7), `note.size() <= 200` (C8)
    and `createdAt == request.time` (C9). NOT given an isolating case (deleting
    the clause changes no outcome, so the clause stays as defense in depth):
    `request.resource.data.guestId is string` (a non-string guest makes the
    link's `mealId + '_' + guestId` a rule evaluation error, which denies), the
    link's `get(req).hostId == hostId` (the `requests` update rule already
    pins the request's `hostId` to the caller, who is what the link is passed)
    and the create's `note is string` (a non-string note makes `note.size()` a
    rule evaluation error, which denies; C8b still passes without it). The
    `requests` create's meal-date conjunct is a single clause on a document the
    create rule already reads, so it adds no new access count.
    D4b (request already denied) is now also denied by the `requests` guard,
    so D4a is the case that isolates the link's `pending` clause. The ratings
    gate's missing-meal case (G3) is denied by the rule evaluation error on
    `get` of a missing doc, not by a dedicated clause.
  - Seeding convention: states the rules forbid (a matched meal, a decided
    request, a past meal, a match doc without a real approve) are seeded with
    `adminSetDoc`/`adminUpdateDoc` (emulator admin REST, rules bypass by
    design), so every case varies one property. The real flows stay covered by
    `request_match_test.dart` (UI approve) and the allowed rules cases above.
  - Manual QA: the create-meal date/time picker now requires the meal to be at
    least 5 minutes ahead and shows "Pick a time at least 5 minutes from now."
    otherwise (it matches the server-side future check). Try a time 2 minutes
    out and one 10 minutes out.
  - Known gaps (deferred, not covered by tests): (a) FIXED
    by the inbox-feedback change (Plan 14): the inbox now shows a snackbar for
    every Approve/Deny outcome, including a stale tile acting on an
    already-decided request (generic "Couldn't approve/deny this request. It may
    already have been handled."). Still open from it: at the server/device
    clock boundary the user sees that same generic message, not a specific
    one. (b) Clock skew: the rate button uses the client clock while the
    rule uses the server clock, so inside the skew window the user sees the
    generic "Couldn't submit your rating" snackbar. (c) The create-meal submit
    path does not re-validate the 5-minute lead, so a pick that ages below the
    server's `request.time` between picking and submitting fails with a generic
    error; the picker's `_submit` should re-check `isMealTimeFarEnough` and
    derive its message from `mealMinLead`.
  - Follow-ups: inbox requests whose meal has passed are now MARKED
    (Plan 14: "Meal time has passed" chip, Approve disabled, Deny enabled), not
    hidden. Still open: hiding them or expiring them server-side (a scheduled
    function that denies stale requests); excluding past requests from the
    app-bar badge count (`pendingRequestCountProvider` still counts them);
    the date/time formatter is now the shared
    `formatMealDateTime` (`lib/core/util/date_format.dart`, renders in the
    viewer's local time) everywhere. Inbox-feedback follow-ups (not done):
    (1) app-wide `outline`-as-text contrast: `outline` is the border token here
    (~1.15:1 on the tile surface) and is used as text colour in ~39 places;
    (2) the past-meal state does not tick while the screen stays open (a Timer
    scheduled to `meal.dateTime` would); (3) the shared `isSubmitting` disables
    every tile's buttons while one request is in flight, including offline,
    where the deny write can stay pending; (4) `requestMealProvider` is not
    autoDispose, so its entries live for the process, including across
    sign-out; (5) in this theme the enabled FilledButton background equals the
    tile's surface, so Approve looks unfilled. (6) FIXED: chat message times
    and the chat list's M/D fallback now render in local time via
    `formatClockTime`/`formatMonthDay` (`toLocal()`). CI's runner is UTC, so a
    dedicated `analyze-test` step re-runs the local-time display tests
    (`date_format_test`, chat widgets, `request_inbox_tile_test`) under
    `TZ=Pacific/Kiritimati` (UTC+14); without it they would pass vacuously.
    Other follow-ups (not done): Discover should skip an unparseable meal
    instead of erroring the whole stream; a cancel-meal Cloud Function
    (clients can no longer withdraw an open meal, since the meals rule has no
    client delete); the rule's `note.size() <= 200` may count Unicode code
    points while the UI `maxLength` counts grapheme clusters: a note of ≤200
    graphemes made of multi-code-point emoji could be denied with a generic
    error (rare; same shape as the rating comment rule).
- **Cloud Functions** — triggers actually fire in the emulator, e.g. the rating
  aggregate written by `onRatingCreated`.
- **Smoke** — a signed-in user boots to the Discover feed.
- **Core flow through the real UI** — guest requests, host approves, match is
  created; chat (host sends, guest reads); both parties rate, including a
  rating with no comment.

**How to run**

```bash
make e2e
```

Prerequisites: Xcode with an iOS Simulator runtime, Node 22, Java 21+ (the
emulators need it), `firebase-tools`, FVM, and a **dedicated simulator** named
`Convyve E2E` (don't share one with other projects running concurrently — that
causes hangs). Create it once:

```bash
xcrun simctl create "Convyve E2E" <iPhone devicetype id> <iOS runtime id>
# ids: xcrun simctl list devicetypes / xcrun simctl list runtimes
```

`make e2e` seeds the iOS plist, boots the simulator, pre-decides the location
permission prompt, builds the Cloud Functions, then runs the whole suite inside
`firebase emulators:exec`. Override the simulator with `make e2e DEVICE=<name or udid>`.

**CI** — the `E2E (emulator, iOS sim)` job in `.github/workflows/ci.yml` runs
the same `make e2e` on a macOS runner. It is **currently non-blocking** (not a
required check); see `docs/CICD.md` for when it gets promoted.

**Known flake notes**

- Occasionally the run hangs after the Xcode build, at the start of
  `smoke_test.dart` (the app launch never completes). CI caps each attempt at
  40 minutes and retries once in place; a green-after-retry run prints a
  warning and uploads the emulator logs. Locally: Ctrl-C and re-run.
- A hang that persists across runs usually means another process is using the
  simulator, or stray emulators hold the ports (`pkill -f firebase`).
- If a test fails, check `firebase-debug.log` / `firestore-debug.log` in the repo
  root (git-ignored) for rule denials and Function errors.

---

## Manual `stage` smoke checklist (user-run, pre-release)

What the emulator suite cannot prove. Run against a real `stage` build before
each release; each item is **user-run**.

- [ ] **Real Google / Apple sign-in** — tap the actual "Continue with Google" and
  "Continue with Apple" buttons (the emulator suite signs in programmatically,
  so the native sign-in sheets and OAuth config are never exercised). Confirm
  new-user and returning-user paths both land correctly.
- [ ] **Push (FCM) delivery on a real device** — request, approve and message
  pushes arrive on a physical device (emulators have no FCM/APNs); cold-start
  tap deep-links correctly; foreground shows the in-app banner only.
- [ ] **App Check enforcement** — with enforcement toggled on for the product
  under test in the Firebase console, a registered build works and an
  unregistered/tampered client is rejected; debug tokens are registered for
  every dev device. The emulators never enforce App Check.
- [ ] **Named `stage` database split** — the `stage` flavor reads and writes the
  `stage` Firestore database, the `prod` flavor the `(default)` one; data
  created in one never appears in the other; rules deployed to both
  (`firebase deploy` covers both, the E2E run only loads `(default)`).

---

## Manual-device checklist (pending — requires a signed build + real device)

The 2026-09-23 QA sweep (Plan 11, Task 8) was a static/automated pass only —
`fvm flutter analyze`, `fvm flutter test`, and the Functions build/test ran
clean, and the code was reviewed, but nothing here was exercised on an actual
simulator, emulator, or device from this environment. These items are **not
satisfied yet** and must be run by the user (or whoever cuts the release)
before shipping, per the pre-release gate below:

- [ ] **Real-device smoke** — full golden path (sign in → age gate/profile →
  discovery → create meal → request/match → chat → rate) on at least one
  physical iOS device and one physical Android device (not simulator/emulator).
- [ ] **Offline write + reconnect** — toggle airplane mode mid-action (send a
  chat message, submit a request) → verify the write queues via Firestore
  offline persistence, UI shows optimistic/cached state (not blank), then
  reconnect and confirm the queued write lands.
- [ ] **Push delivery end-to-end** — now unblocked by Blaze + APNs/Android SHA-256
  (see build-state memory) if configured: request/approve/message pushes
  actually arrive on a real device; cold-start tap on a push deep-links
  correctly; foreground message shows an in-app banner, not a duplicate
  system notification.
- [ ] **Deep links** — cold-open the app via each `go_router` deep link
  (`/chats/:matchId`, `/meals/detail`, a push-notification tap) and confirm it
  lands on the right screen without a redirect loop or crash.
- [ ] **Cold start to right screen** — force-kill, relaunch, confirm the app
  reaches the correct screen (signin / age-gate / profile-setup / home) within
  3s on a mid-tier Android device.
- [ ] **Dark mode parity** — every shipped screen (auth, onboarding, discovery,
  meal detail, requests inbox, chat, settings, rating sheet, report sheet) in
  both `ThemeMode.light` and `ThemeMode.dark`.
- [ ] **Dynamic type** — `MediaQuery.textScaler` at 1.5–2.0x on the same screen
  list; confirm no truncated/overlapping critical text (sign-in, request
  buttons, chat composer, settings rows).
- [ ] **VoiceOver / TalkBack** — walk every interactive element on the golden
  path (sign-in buttons, age-gate DOB picker, meal card, request/approve/deny
  buttons, chat composer + send, rating stars, report chips, settings rows,
  delete-account confirmation) and confirm a screen reader announces a
  meaningful label for each.
- [ ] **Firestore rules — live verification** — Rules Playground or the
  Firestore emulator, not just code review: non-owner denied on `users/{uid}`,
  `requests`, `matches/{id}/messages`, `matches/{id}/reads`, `fcmTokens`; block
  bidirectionality; women-only meal gate; reports create-only.
- [ ] **Memory/perf** — 5 min of typical use in DevTools memory tab (flat
  line, no runaway growth), no dropped frames (>16ms) on the discovery feed
  scroll with 100+ seeded meals.
- [ ] **Slow-3G throttle** — discovery feed load, chat send, meal creation
  still complete (with visible loading state) rather than hanging or
  crashing.

None of the above can be exercised from this sweep's environment (no
simulator/emulator/device access here) — they gate the release per
`docs/TEST-PLAN.md`'s own rule ("No release ships without a green run of this
plan on iOS Simulator + Android Emulator + at least one real device") and must
be run before `/release` signs off.

---

## Pre-release gate (must pass — no exceptions)

Before `/release` cuts a build:

- [ ] `flutter analyze` is clean (zero warnings)
- [ ] `flutter test` is green
- [ ] `make e2e` (emulator E2E suite) is green on the iOS Simulator; `flutter test integration_test` on an Android Emulator is not wired yet
- [ ] Golden tests pass on the canonical host (no unintentional re-baselines)
- [ ] All universal edge cases pass on iOS + Android simulator
- [ ] All feature checklists for this release pass
- [ ] Zero open P0/P1 bugs (`docs/bugs/`)
- [ ] No new console warnings introduced this release
- [ ] Real-device smoke test (NOT simulator) on at least one device per platform
- [ ] Memory + perf check (DevTools — flat memory line, no jank > 16ms in steady state)
- [ ] Firestore rules deployed to the matching environment

---

## How to file a failure

When a checkbox doesn't pass:

1. Run `/bug <title> — <repro>` — files `docs/bugs/<YYYY-MM-DD>-<slug>.md`.
2. Link the bug slug under the relevant checklist item: `- [ ] {{step}} — see bug-<slug>`.
3. Don't uncheck other items just because one failed — keep the rest green so the team sees what *does* work.
