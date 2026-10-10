## [P2] Chat: pinned safety-tips/post-meal cards leave 22-100dp for the thread while typing, and overflow at 1.5x text

**Repro:**
1. Open a chat (`/chats/:matchId`) after the meal time has passed (so the post-meal rating card is visible) on a 360dp-wide phone.
2. Tap the composer so the software keyboard opens (about 280-300dp).
3. Repeat on a 360x640 phone, and on a 360x800 phone with system font scale 1.5x.

**Expected:** The message thread stays usable (at least ~2 bubbles) above the composer; no RenderFlex overflow at 1.5x (project bar, docs/DESIGN.md).
**Actual:** `ChatScreen` (`lib/features/chat/presentation/chat_screen.dart` ~L139) is a non-scrolling `Column`: `PostMealCard` + `SafetyTipsCard` (4 bullets, always shown) + `Expanded(list)` + composer. Measured with the real Nunito font:
- 360x640, 1.0x, keyboard 280dp: thread height 22dp (effectively invisible).
- 360x800, 1.0x, keyboard 300dp, post-meal card shown: thread 100dp.
- 360x800, 1.5x, keyboard 300dp, post-meal card shown: "RenderFlex overflowed by 79 pixels on the bottom" (composer pushed off-screen in release).
- 360x640, 1.5x, no keyboard: OK.

**Device/OS:** flutter_test harness with Nunito loaded (360x640 and 360x800 @1x). Not seen on hardware.
**Build:** develop @ 8cf1b41
**Frequency:** always under those conditions.

**Hypothesis:** Make the tips card collapsible/dismissible (or move it into the app bar overflow / a one-time banner) and put the cards inside the scrollable thread (as list header) instead of a fixed header; hide the tips while the keyboard is open (`MediaQuery.viewInsetsOf(context).bottom > 0`).

**Regression tests:** `test/features/chat/presentation/chat_screen_edge_test.dart` (3 cases skipped with `bug = true`; flip the constant when fixed).

**Status:** Fixed — the post-meal card and safety tips are hidden while the keyboard is open and otherwise capped at 40% of the screen height (they scroll); the thread keeps the rest. Regression tests un-skipped (`chat_screen_edge_test`).
