# UX Pass Part B, Plan 18: Requests, Chat, Report/Rating Sheets, Settings, Profile

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the screens a host and a matched pair use after the first meal request: a request inbox where Approve is the primary action and one slow action doesn't freeze every tile, a chat that says which meal it is about and no longer wastes its top third on safety copy, report/rating sheets that name who they are about, a Settings screen organised into Account / Safety / Notifications / Legal / About with a Blocked-people screen, and a profile tab whose Save only enables when something changed.

**Architecture:** Presentation changes in `features/matching`, `features/chat`, `features/safety`, `features/rating`, `features/settings`, `features/user`, plus ONE small domain+data addition (a "blocked by me" stream on `BlockRepository`) for the Blocked-people screen, and a cancelled-meal state in the meal-detail action bar. Built on the 16a/16b/17a/17b foundations (`AppButton`, `ErrorState`, `EmptyState`, `SkeletonList`/`SkeletonMessages`, `context.wp`, stable router, 24 h Paris dates, pinned action bar). French/`intl` comes in plan 19: new strings stay English, in place.

**Tech Stack:** Flutter via FVM (`fvm flutter ...`), Riverpod, go_router, `flutter_test` + `mocktail`.

Spec: `docs/superpowers/specs/2026-10-05-ux-pass-design.md` (§6: Settings scope = core set + Blocked people + iOS notification row + language switch (the language switch itself lands with French in plan 19); no "My meals"). Evidence: `docs/ux/AUDIT.md` REQ-01..06, CHATS-01/02, CHAT-01..07, REPORT-01..04, RATE-01..04, PROF-01..04, SET-01..04 (backlog B4-1..B4-7, B5-1..B5-4). Inputs from earlier plans: `docs/ux/17b-verification.md` (D11 `settleOrQueue` hides a slow rejection; D12 "Can't make it" leaves "Open chat" on a cancelled meal; xxl overflows in chat 55 px, report sheet 11 px, rating sheet 118 px).

IMPORTANT, develop has moved and another session keeps changing these screens. Before writing code, read the CURRENT files on this branch and `git log -5 -- <file>`; keep develop's behaviour and tests: chat keyboard-aware layout with the post-meal card and safety tips in a max-40% scroll area (`fix(ui): no overflow at large text sizes`), the chat "no longer available" state for a cancelled match (`_isChatGone` on permission-denied) with `chat_unavailable_back_button`, "Can't make it" (`leave_match_action.dart`), per-user providers that follow the auth session, `avatarImage` decoded at avatar size, accessible names for icon-only controls (`test/core/a11y/icon_only_controls_semantics_edge_test.dart`), the Contact-support row and `supportEmail` in Settings, `settleOrQueue` offline grace. Do not redo what is already fixed; verify first with the 17b captures (`docs/ux/shots-17b/`, `ux_audit/out/`) and say in each report which audit finding was already closed by develop.

## Global Constraints

- Flutter via FVM always. `fvm flutter analyze`: 0 errors AND 0 warnings (CI fails on warnings, including `unused_element`), no new lints in touched files. `fvm flutter test` green after every task.
- Dependency rule `presentation → application → domain ← data`; Firebase imports only in `data/`. Strings English, in place; no `intl`, no new packages.
- Tokens for all colours, spacing, type, radius, sizes (`WarmPlayfulSize.actionHeight` 56, `minTap` 48, `spinner` 20, `keyboardReveal`); no magic numbers. `context.wp` for muted/dangerText; never `colorScheme.outline` as text or icon colour (grep test).
- Accessibility: tap targets >= 48, semantics for icon-only controls and state changes (`Semantics(liveRegion: true, container: true)`), no overflow at 320 px width and `TextScaler.linear(2.0)`, primary actions never under the keyboard.
- Keep every existing `Key` used by `integration_test/` or tests (inbox tile/approve/deny keys, `request_inbox_tile_$id`, chat keys, `settings_*` keys, report/rating submit keys); E2E scenarios (`request_match_test`, `inbox_feedback_test`, `chat_test`, `rating_test`) must stay green: run `make e2e` once at the end.
- Skeleton/ErrorState tests: `pump(Duration)` (1 ms twice), never `pumpAndSettle` while a skeleton is on screen (docs/MASTER-SPEC.md gotcha 6).
- Unmount-after-await rule: never use `ref`/`context` after an await in widgets/controllers; read dependencies before the await (see Settings sign-out, which reads `pushRepositoryProvider` and the uid before its dialog).
- Stable router (plan 16b): add routes only (Blocked people, Safety tips) in `lib/core/routing/router.dart`; do not touch `authRedirect` or the listeners.
- Rules: NO `firestore.rules`, Cloud Functions or CI workflow changes. The existing `blocks` rule allows `read` when `uid in resource.data.pair` and `delete` for the blocker: the Blocked-people stream MUST be a query the rules can prove: `where('pair', arrayContains: uid)` and filter `blockerUid == uid` client-side (a `blockerUid ==` query alone is denied). No firebase deploy.
- Do NOT run `dart format` on directories or on files you do not otherwise edit; format only new files; check `git status` shows only intended files before every commit. Do not commit anything under `graphify-out/`, `.superpowers/`, `ux_audit/out/`. Commit trailer: the `Co-Authored-By:` line the harness specifies at that time.
- Capture runs use only the simulators `Convyve E2E` and `Convyve UX Small`, never the generic `iPhone 17 Pro`.

---

### Task 1: Request inbox

**Files:**
- Modify: `lib/features/matching/presentation/widgets/request_inbox_tile.dart`, `lib/features/matching/application/inbox_action_controller.dart`, `lib/features/matching/presentation/request_inbox_screen.dart`, `lib/core/routing/app_shell.dart` (tab icon)
- Tests: `test/features/matching/presentation/widgets/request_inbox_tile_test.dart`, `request_inbox_screen_test.dart`, `test/features/matching/application/controllers_test.dart` (inbox controller), `test/core/routing/app_shell_test.dart`

**Interfaces:**
- `InboxActionController` state tracks WHICH request is in flight: e.g. `state: AsyncValue<void>` plus a `String? pendingRequestId` (or a small immutable `({String? requestId, InboxAction? action})` value). `approve`/`deny` keep returning `Future<Object?>` (the error) so the tile's snackbar logic and `keepAlive` stay. A tile is "busy" only when `pendingRequestId == request.id`; other tiles' buttons stay enabled (REQ-02).
- Approve = primary `AppButton` (56, full row on small widths); Deny = `AppButton` text variant with `dangerText` foreground; both inside an `OverflowBar(alignment: end, overflowAlignment: end, spacing: ...)` so they stack when they do not fit (REQ-03). The in-flight spinner shows in the pressed button of that tile only (use `AppButton.isLoading`).
- `RatingBadge(uid: guestId)` under the guest name (existing widget; REQ-04). Past-meal chip colours come from the container roles already mapped in 16a (REQ-06 closed).
- Requests tab icon: `Icons.inbox_outlined` / `Icons.inbox` with the existing `Badge` (REQ-05: remove the built-in "unread dot" icon `mark_email_unread`).

- [ ] **Step 1: Tests first (red).** (a) Two tiles: tapping Approve on A (held controller future) shows a spinner in A's Approve only; B's buttons stay enabled and tappable; (b) at 320 px / 2.0x the actions stack, no overflow, both buttons >= 48 high and visible; (c) Approve is the `FilledButton` primary (fill = primary), Deny text button in `dangerText` (contrast >= 4.5 in both modes); (d) the guest's `RatingBadge` renders under the name; (e) tab icon is the inbox icon and the badge shows only for a nonzero count; (f) the unmount-mid-flight tests keep passing (tile removed while the action is in flight: no exception, snackbar still shown); (g) existing tests of the 5 snackbar outcomes still pass.
- [ ] **Step 2: Implement.** Keep `_run` capturing messenger/router/accessibleNavigation before the await.
- [ ] **Step 3: Gates; commit** `feat(requests): Approve is the primary action, busy state is per request, actions stack at large text, guest rating shown, inbox tab icon`

---

### Task 2: Chat

**Files:**
- Modify: `lib/features/chat/presentation/chat_screen.dart`, `widgets/message_bubble.dart`, `widgets/message_composer.dart`, `widgets/chat_list_tile.dart`, `lib/features/chat/presentation/chat_list_screen.dart`, `lib/features/safety/presentation/widgets/safety_tips_card.dart`
- Create (if needed): `lib/features/chat/presentation/widgets/chat_meal_header.dart`, `day_separator.dart`, `lib/features/safety/presentation/safety_tips_sheet.dart`
- Tests: existing chat tests under `test/features/chat/` and `test/features/safety/`

**Interfaces:**
- `ChatMealHeader`: compact pinned row under the app bar, "Pizzeria Popolare · Tue 6 Oct, 20:30" (`formatMealDateTime`, `wp.muted`, one line ellipsis), tap opens the meal detail (the same navigation the post-meal card or `matchMealProvider` already uses: read `post_meal_card.dart`), hidden while the meal is loading or missing (no spinner). Data: `matchMealProvider` (already exists).
- The safety tips card becomes a one-line tappable banner "Meeting up? Safety tips" (dismissible per chat via local state, not persisted) opening `SafetyTipsSheet` (bottom sheet, same four tips as today's card, scrollable); the post-meal card scrolls with the messages as the first/last list item (not a fixed card above the list). Keep develop's keyboard-aware layout and the cancelled-match state; the list is the only flexible child.
- Day separators: a centred label ("Today", "Yesterday", `Mon 5 Oct`) between messages of different local days; a timestamp only on the last bubble of a same-sender run within 5 minutes (CHAT-05). Pure helper `groupMessages(List<ChatMessage>, now)` in `lib/features/chat/presentation/` with unit tests (local days, DST-safe via calendar fields, Kiritimati/Los_Angeles zones).
- Composer clears immediately on send and restores the text if the send fails (CHAT-06); keep the existing send-button spinner, key and the offline queued behaviour (`settleOrQueue`).
- Chat list tile: second line with the meal context "Pizzeria Popolare · Tue 20:30" (`matchMealProvider`, muted, ellipsis; no extra spinner: omit the line until loaded); `EmptyState` "No chats yet" + "Find a meal" action to Discover (CHATS-02); unread dot and avatar keep develop's accessible names.

- [ ] **Step 1: Tests first (red).** Banner replaces the fixed card (no `Card` above the list; banner height one line); sheet opens with the four tips; at 320x568 / 2.0x with the keyboard up the messages list keeps >= 200 px and the composer is on screen (the audit's P0: chat unusable at xxl); meal header shows restaurant + date, tap navigates, absent when the meal is unavailable; day separators and run-timestamp grouping (pure function tests + one widget test); composer clears at once and restores on failure; chat list second line and empty state action; all develop chat tests (cancelled-match, edge tests) still green.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Gates; commit** `feat(chat): safety tips as a banner and sheet, meal header, day separators, composer clears at once, meal context in the chat list`

---

### Task 3: Report sheet, rating sheet, block dialog

**Files:**
- Modify: `lib/features/safety/presentation/report_sheet.dart`, `widgets/safety_actions.dart`, `lib/features/rating/presentation/rating_sheet.dart`, `widgets/post_meal_card.dart`
- Tests: `test/features/safety/presentation/`, `test/features/rating/presentation/`

- [ ] **Step 1: Tests first (red).** (a) Report title names the target ("Report Bastien" / "Report this meal": pass a display name/label into the sheet from the callers: chat knows the partner's name, meal detail knows the host/meal); note field `textInputAction: TextInputAction.done`, with a visible boundary (1 px `wp.muted` enabled border or `bg` fill inside sheets: `inputDecorationTheme` for sheets) and Submit visible/reachable with the keyboard (develop's scrolling fix stays; keep its tests); selected reason chip label readable (>= 4.5:1 both modes); (b) block dialog "Block Bastien?" naming the person, confirm button in `dangerText`, cancel neutral; (c) rating sheet title "How was your meal with Giulia?", unselected stars `wp.muted` outline (>= 3:1 on the sheet), selected stars filled; (d) both sheets: no overflow at 320 px / 2.0x; the post-meal card "Rate" is the primary button (AppButton) and names the person ("Rate Giulia"); (e) semantics: stars have labels "1 star" … "5 stars" with selected state (X-14 from the audit; check what develop's a11y commit already covers and only add what is missing).
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Gates; commit** `feat(safety,rating): sheets name who they are about, stars and chips readable, block confirm in danger colour`

---

### Task 4: Settings structure and Blocked people

**Files:**
- Modify: `lib/features/settings/presentation/settings_screen.dart`, `lib/core/routing/router.dart` (two routes: `/settings/blocked`, `/settings/safety`), `lib/features/safety/domain/repositories/block_repository.dart`, `lib/features/safety/data/repositories/block_repository_impl.dart` (+ its providers file)
- Create: `lib/features/safety/presentation/blocked_people_screen.dart`, `lib/features/safety/presentation/safety_tips_screen.dart` (reuses the Task 2 sheet content), `lib/features/safety/application/blocked_people_provider.dart`
- Tests: `test/features/settings/presentation/settings_screen_test.dart`, `test/features/safety/` (new screen, repository)

**Interfaces:**
- `BlockRepository` gains `Stream<Set<String>> watchBlockedByMe(String uid)`: the `blockedUid`s of blocks where `blockerUid == uid` (query `pair array-contains uid`, filter client-side; the rules cannot prove a `blockerUid ==` query). `unblock(blocker, blocked)` already exists. Data-layer test with the existing fake Firestore setup (check how `block_repository_impl` is tested).
- `BlockedPeopleScreen`: AppBar "Blocked people"; list of rows (avatar via `avatarImage`, name from the public profile stream `UserRepository.watch(uid)` (profiles split: it reads the public doc), 'Unblock' `AppButton` outlined, row-level loading while the unblock runs, a confirm-free action with a snackbar "Unblocked Bastien. Undo" (undo re-blocks) OR a plain snackbar without undo: choose the plain snackbar (YAGNI) and say so); `EmptyState` "You haven't blocked anyone" (icon, no action); skeleton rows while loading; `ErrorState` with retry. A blocked profile that no longer exists shows 'Unknown user'.
- Settings groups and order (keys of existing rows kept): **Account** (Edit profile → `/profile`; Phone number read-only with the signed-in number from the auth repository `currentUser.phoneNumber` formatted with `formatPhoneDisplay`; Sign out (existing confirm); Delete account lives LAST, separated, in `dangerText`), **Safety** (Blocked people → `/settings/blocked`; Safety tips → `/settings/safety`; Contact support (existing row, keep its key and `supportEmail`)), **Notifications** (one row "Notification settings" opening the OS settings for the app: use a package ALREADY in `pubspec.yaml` if one can open app settings (`permission_handler`/`app_settings`/`firebase_messaging`? check; if none is available add NOTHING: render the row disabled-looking? NO: stop and report NEEDS_CONTEXT instead of adding a dependency), **Legal** (Privacy Policy, Terms, Open-source licences via `showLicensePage` with the app name and version), **About** (Version). Section headers `wp.muted` labelLarge-ish (existing `_SectionHeader`), chevrons on navigating rows, tap targets >= 48.
- Language row: NOT in this plan (plan 19 adds it with French).

- [ ] **Step 1: Tests first (red).** Repository `watchBlockedByMe` (only my blocks: a block where I am the blocked side is excluded; two blocks; none), the provider, the screen (data, empty, loading skeleton, error + retry, unblock calls the repository once and the row leaves, in-flight spinner in that row only), Settings (group order and headers, each navigating row's route (use a fake router), phone shown/hidden when null, Delete account last in `dangerText` with its key and spinner behaviour unchanged, Contact support untouched, sign-out confirm and push-token unregister tests from 17b still green, licences row opens the licence page), no overflow at 320 px / 2.0x.
- [ ] **Step 2: Implement** the repository addition (domain interface first), providers, screens, routes, Settings.
- [ ] **Step 3: Gates; commit** `feat(settings): grouped Settings with phone, blocked people, safety tips, licences and notification settings; blocked-people screen with unblock`

---

### Task 5: Profile tab and the cancelled-meal state

**Files:**
- Modify: `lib/features/user/presentation/profile_edit_screen.dart`, `lib/features/user/presentation/widgets/profile_form.dart` (dirty tracking via the existing form-data type), `lib/features/meal/presentation/widgets/meal_action_bar.dart`
- Tests: `test/features/user/presentation/`, `test/features/meal/presentation/meal_action_bar_test.dart`

- [ ] **Step 1: Tests first (red).** Profile (PROF-02/03): title "Profile"; label "Your rating ★ 4.7 (7)" (or the existing rating widget with a visible label); Save is disabled until something changed (compare form data with the loaded user), enabled after an edit, disabled again after saving; on success a snackbar "Profile saved" and the screen STAYS (it is a tab root: no `Navigator.pop`); a "Settings" gear stays; no overflow at 320 px / 2.0x; keyboard-safe (setup's patterns). Action bar: `MealStatus.cancelled` (and any closed status the domain has) is handled BEFORE the request state: a cancelled meal shows a tonal disabled 'Meal cancelled' button and status 'The host cancelled this meal.' (the bar keeps one fixed height) even if the viewer's request is approved (D12); matched/open meals unchanged; read how `MealStatus` is modelled and what develop's 'Can't make it' flow writes (`leave_match_action.dart`) to be sure which field changes.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Gates; commit** `feat(profile,meal): profile Save only when changed with a confirmation; cancelled meals are shown as cancelled on meal detail`

---

### Task 6: Docs, verification capture, final gates

**Files:**
- Modify: `docs/DESIGN.md` (inbox actions, chat anatomy (banner, meal header, separators), sheets, Settings structure table, Blocked people, profile Save rule), `CHANGELOG.md`, `docs/TEST-PLAN.md` (new tests; manual QA: VoiceOver on inbox buttons and chat banner, blocked-people unblock on a real account, OS notification settings row, licence page)
- Create: `docs/ux/18-verification.md`, `docs/ux/shots-18/` (<= 8 downscaled PNGs, each < 400 KB)
- Modify (if steps changed): `ux_audit/capture_test.dart` (chat banner, blocked people, settings groups, profile save), `ux_audit/README.md`

- [ ] **Step 1: Docs** accurate to what shipped (widget-tested vs only seen in capture).
- [ ] **Step 2: Capture** `make ux-capture DEVICE='Convyve E2E' OUT=18-light-default` (must exit 0), dark (`xcrun simctl ui <udid> appearance dark`, restore light afterwards, also on failure), and the xxl small-phone cell via `tool/ux_matrix.sh --only se3-light-xxl` (it restores appearance/content_size and deletes the cell directory). Add shots for the new states (blocked people list/empty, settings top and bottom, chat banner + sheet, chat with day separators). View BEFORE (17b / audit) vs AFTER for requests (52-55), chats (60-62), chat (63-66, 72), report/rating sheets (68-75), settings (83-85), profile (80). Count UXOVERFLOW lines in `ux_audit/out/logs/se3-light-xxl.findings.txt` before (6 at 17b: chat 55, report 11, rating 118) vs after. Write `docs/ux/18-verification.md` (what changed per shot; remaining defects with severity and owner: plan 19 French/language row; follow-ups: typed `createRequest` failure so 'no longer open' can show, `settleOrQueue` 3 s hiding slow rejections, notice persistence, Google mark, Android auto-verify). Copy at most 8 downscaled shots (`sips -Z 900`, < 400 KB) into `docs/ux/shots-18/`.
- [ ] **Step 3: Final verification, once, in order:** `fvm flutter analyze` (0 errors/warnings), `fvm flutter test`, date-sensitive CI files under `TZ=Pacific/Kiritimati` and `TZ=America/Los_Angeles` (read the current `.github/workflows/ci.yml`), `make e2e` (all green; run in the background with a log and bounded polling; rerun once if the intermittent launch hang hits; say precisely whether a failure is these changes or flake).
- [ ] **Step 4: Commit** `docs: UX plan 18 (requests, chat, sheets, settings, profile): design system, changelog, test plan, verification capture`
- [ ] **Step 5:** The controller pushes and opens the PR after the final review.
