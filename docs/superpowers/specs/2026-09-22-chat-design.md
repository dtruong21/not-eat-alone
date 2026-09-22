# Convyve — Chat Design (Plan 7)

**Date:** 2026-09-22
**Status:** Approved (design), pending implementation plan
**Feature:** Realtime 1:1 chat on a match, with read receipts and rules that restrict every message to the two matched parties. Introduces the app's bottom-navigation shell (Discover / Chats / Requests / Profile). Built on the `matching` (matches) and `user` features.

---

## 1. Goal & constraints

Two matched users (the host and the approved guest of a meal) can open a chat, exchange text messages in realtime, and see when the other has read them. A third user is denied by Firestore rules. No new backend infrastructure — realtime is Firestore `.snapshots()`; there is no push yet (Plan 8). Text only in v1 (no media). The chat lives behind a new bottom-navigation shell so the app has real information architecture for its now-multiple destinations.

## 2. App shell — bottom navigation (new)

The app currently routes discovery at `/` and the requests inbox at `/requests` as flat routes. Plan 7 introduces a persistent bottom navigation using go_router's `StatefulShellRoute.indexedStack`, so each tab keeps its own navigation stack.

- `core/routing/app_shell.dart` — a `StatefulShellRoute.indexedStack` with four branches; the shell widget renders a Material 3 `NavigationBar`:
  1. **Discover** — the existing `DiscoveryScreen` (moved from `/` into this branch, at `/discover`).
  2. **Chats** — the new `ChatListScreen` (`/chats`).
  3. **Requests** — the existing `RequestInboxScreen` (moved from a flat `/requests` into this branch). The pending-request count (`pendingRequestCountProvider`) becomes a `NavigationDestination` badge; the app-bar inbox action added to discovery in Plan 6 is removed (the tab replaces it).
  4. **Profile** — the existing but unrouted `ProfileEditScreen` (`/profile`).
- `authRedirect` semantics are unchanged: a fully-onboarded user lands in the shell (default branch `/discover`). The redirect still only special-cases the literal auth/onboarding paths; the shell routes are normal in-app destinations. Update any hardcoded post-onboarding target from `/` to `/discover`.
- Deep routes that must sit *above* the shell (full-screen, no bottom bar): `/meals/new`, `/meals/new/details`, `/meals/detail`, and the chat screen `/chats/:matchId` push over the shell. Requests and discovery detail flows keep working.

The shell is delivered as its own task(s) before chat, so the tree stays green and chat plugs into the Chats tab.

## 3. Match model change — `participants`

The chat list needs "all matches where I am a participant" in one query. Firestore cannot OR across two fields, so the match doc gains `participants: [hostId, guestId]` and the list queries `where('participants', arrayContains: uid)`.

- `matching/domain/entities/match.dart` — add `@Default(<String>[]) List<String> participants`.
- `matching/data/repositories/request_repository_impl.dart` — the **approve transaction** (Plan 6) now writes `participants: [request.hostId, request.guestId]` into the `matches/{mealId}` document alongside the existing fields. Its DTO/mapper carry the field.
- `matching` gains `MatchRepository.watchMatchesForUser(String uid) → Stream<List<Match>>` using the array-contains query, ordered by `createdAt` desc. (Implemented on the existing matching repository impl or a small dedicated `MatchRepositoryImpl`; bound via a provider.)
- Migration: the handful of pre-Plan-7 matches (pre-launch, stage only) lack `participants` and simply won't appear in the array-contains list. Acceptable — no backfill. The `matches` read rule keeps the host||guest condition OR'd with the participants check so those old docs stay readable if reached directly.

## 4. `chat` feature (clean layers)

```
lib/features/chat/
  domain/
    entities/     chat_message.dart, message_read.dart
    repositories/ chat_repository.dart
  data/
    dtos/         chat_message_dto.dart, message_read_dto.dart
    mappers/      chat_message_mapper.dart, message_read_mapper.dart
    repositories/ chat_repository_impl.dart
  application/    chat_providers.dart, chat_controller.dart,
                  chat_messages_provider.dart, chat_read_provider.dart,
                  chat_list_provider.dart
  presentation/   chat_list_screen.dart, chat_screen.dart,
                  widgets/ message_bubble.dart, chat_list_tile.dart, message_composer.dart
```

### Entities (pure freezed, no json)

- `ChatMessage { String id, String matchId, String senderId, String text, DateTime? createdAt }` — `createdAt` nullable for optimistic snapshots (serverTimestamp).
- `MessageRead { String uid, DateTime? lastReadAt }`.

### Storage

- Messages: subcollection `matches/{matchId}/messages/{messageId}` (auto-id). Ordered by `createdAt` ascending in the chat; realtime via `.snapshots()`.
- Reads: `matches/{matchId}/reads/{uid}` doc `{ lastReadAt }`, one per participant, owner-written when they open/scroll the chat.

### Repository interface (`chat_repository.dart`)

```dart
abstract class ChatRepository {
  /// Realtime message stream for a match, oldest-first.
  Stream<List<ChatMessage>> watchMessages(String matchId);

  /// Append a text message (senderId = current uid, createdAt = serverTimestamp).
  Future<void> sendMessage({required String matchId, required String senderId, required String text});

  /// Upsert the current user's lastReadAt = now for a match.
  Future<void> markRead({required String matchId, required String uid});

  /// Watch a participant's read state (to render "Seen").
  Stream<MessageRead?> watchRead({required String matchId, required String uid});
}
```

### Data layer

- DTOs freezed + json; `Timestamp` ↔ `DateTime` handled in mappers (UTC ISO on read, `serverTimestamp()` / `Timestamp` on write), same convention as `matching`.
- `chat_repository_impl.dart` — the only `chat/**` file importing `cloud_firestore`; uses the flavor-aware `db`. `watchMessages` maps the subcollection snapshot; a parse failure throws `RepositoryParseException`. `sendMessage` trims + guards non-empty and a length cap (≤ 2000 chars) before write, throws `RepositoryWriteException` on failure. `markRead` writes `reads/{uid}` with merge.

## 5. Firestore rules

Under `matches/{matchId}` (which already restricts the doc to host/guest), add subcollection blocks. A helper reads the parent match:

```
function matchParticipant(matchId) {
  let m = get(/databases/$(database)/documents/matches/$(matchId)).data;
  return isSignedIn() && (request.auth.uid == m.hostId || request.auth.uid == m.guestId);
}

match /matches/{matchId} {
  // ... existing read/create/update rules ...
  // (read rule broadened to also accept participants array-contains uid)

  match /messages/{messageId} {
    allow read: if matchParticipant(matchId);
    allow create: if matchParticipant(matchId)
                  && request.resource.data.senderId == request.auth.uid
                  && request.resource.data.text is string
                  && request.resource.data.text.size() > 0
                  && request.resource.data.text.size() <= 2000;
    allow update, delete: if false;
  }

  match /reads/{uid} {
    allow read: if matchParticipant(matchId);
    allow write: if matchParticipant(matchId) && uid == request.auth.uid;
  }
}
```

The parent `matches` read rule is broadened to `... || request.auth.uid in resource.data.participants` (kept alongside the host/guest check). Deploy to the single project (both databases share the file).

## 6. Application (Riverpod)

- `chat_providers.dart` — `chatRepositoryProvider` binds the impl; `matchRepositoryProvider` (matching) for the list.
- `chat_messages_provider.dart` — `chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>` (matchId) → `watchMessages`.
- `chat_read_provider.dart` — `otherReadProvider = StreamProvider.family<MessageRead?, ({String matchId, String otherUid})>` → `watchRead` (drives "Seen").
- `chat_controller.dart` — `@riverpod` AsyncNotifier: `send(matchId, text)` (uid from auth, guards empty, fires `message_sent`), `markRead(matchId)` (on open + on new inbound messages).
- `chat_list_provider.dart` — combines `matchRepositoryProvider.watchMatchesForUser(myUid)` with, per match, the last message + my `reads` doc to compute an unread flag; exposes `AsyncValue<List<ChatListItem>>` (view model: match, otherUid, lastMessagePreview, lastMessageAt, unread). Fires `chat_opened` lives in the screen, not here.
- Guest/host display for tiles + chat header reuse `userDocProvider(otherUid)` from the `user` feature.

## 7. Presentation

- `chat_list_screen.dart` (Chats tab) — consumes `chat_list_provider`: loading / error / empty ("No chats yet — match on a meal to start talking") / list. Each row = `chat_list_tile.dart`: other participant photo + name, last-message preview (or "Say hi 👋"), relative time, an unread dot. Tap → `/chats/:matchId`.
- `chat_screen.dart` (`/chats/:matchId`, pushed over the shell) — app bar with the other participant's name/photo (tap → their profile later); a reversed `ListView` of `message_bubble.dart` (mine vs theirs, timestamp, and a "Seen" marker under my latest message once the other's `lastReadAt` ≥ its `createdAt`); `message_composer.dart` (text field + send, disabled while empty/sending). On first build and whenever new inbound messages arrive, call `chat_controller.markRead`. Fires `chat_opened` on entry. All `AsyncValue` states rendered.
- Meal-detail "Matched!" banner (Plan 6) becomes a button that navigates to `/chats/:matchId` (matchId == mealId).
- Tokens (warm-playful) for all styling; no magic numbers.

## 8. Analytics

Declared in `events.dart` + `docs/TRACKING-PLAN.md`, no PII:
- `chat_opened`
- `message_sent`

## 9. Routing

- Introduce the `StatefulShellRoute` shell (§2) with branches `/discover`, `/chats`, `/requests`, `/profile`.
- `/chats/:matchId` → `ChatScreen` (pushed above the shell; `matchId` path param; null/again-guard → back to `/chats`).
- Keep `/meals/*` routes above the shell. Remove the flat `/` discovery route in favor of `/discover` (redirect `/` → `/discover`), and the flat `/requests` becomes the Requests branch.
- `authRedirect` still returns null for in-shell paths; post-onboarding target updated to `/discover`.

## 10. Testing

- Entities/DTOs: `ChatMessage` / `MessageRead` round-trip incl. null timestamps; `Match` with `participants`.
- `chat_repository_impl` (fake_cloud_firestore): `sendMessage` writes under the right subcollection with senderId + trims/guards empty and the 2000 cap; `watchMessages` streams oldest-first; `markRead` upserts `reads/{uid}`; `watchRead` streams the other's lastReadAt.
- `matching` `watchMatchesForUser` returns only matches whose `participants` contains the uid, newest first; the approve transaction now writes `participants`.
- Controllers: `send` fires `message_sent` and no-ops on blank; `markRead` writes; error surfaces to state.
- Rules (manual/emulator note in TEST-PLAN): a participant reads/writes messages + reads; a **third signed-in user is denied** read and create on both subcollections; non-sender cannot forge `senderId`.
- Widgets: chat list renders rows + unread dot + empty state; chat screen renders mine/theirs bubbles, the "Seen" marker toggles with the other's read stream, composer disabled when empty; the shell renders 4 tabs and switches branches; requests badge shows the pending count on the tab.

## 11. Non-goals (deferred)

- Media/image/voice messages, attachments.
- Typing indicators, reactions, message edit/delete/unsend.
- Push notification on a new message (Plan 8) — the chat is realtime only while open.
- Block / report / moderation of messages (Plan 9).
- Group chat / multi-party (v1 is strictly 1:1).
- Pagination / lazy-loading of long histories (fine at launch volume; add later).

## 12. Delivery

Own plan on branch `feature/plan-7-chat` (off `develop`), executed subagent-driven. Ordered so the tree stays green: bottom-nav shell (routes + tabs, existing screens moved in) → match `participants` + `watchMatchesForUser` + approve-transaction update + rules → chat entities/DTOs/mappers → chat repository impl (messages + reads) → providers + controller + analytics → chat list screen + chat screen + composer + banner deep-link + routing → verify/build/PR to `develop`.
