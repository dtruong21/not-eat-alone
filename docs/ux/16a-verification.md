# UX plan 16a: verification capture

Plan 16a (tokens, buttons, font, card separation) checked on the real app, iPhone 17 Pro simulator ("Convyve E2E"), default text size.
BEFORE = the audit capture (`ux_audit/out/iphone17-{light,dark}-default/`), AFTER = `make ux-capture ... OUT=16a-light-default` and `OUT=16a-dark-default` (65 shots each, none blank; local only, not committed). Selected AFTER shots (downscaled, light unless noted): `docs/ux/shots-16a/`.
Seed times differ between runs (status-bar clock, "tonight"), compare structure only.

## Per shot

| Shot | What changed | Verdict |
|---|---|---|
| `01_signin` (light) | Subtitle "Sign in to get started." and the "or" divider label were invisible (border colour), now readable muted text. Google/Apple buttons were coral text on a near-invisible outline: now dark label, 1.5 px muted outline (visible). "Send code" was a faint peach slab, now the coral primary with a brown label. Font is Nunito in the buttons (was the system font). | Fixed |
| `22_discover_data` | Date and distance lines on every card were invisible: now readable. Cards are separated from the cream page by the deeper peach and a soft shadow. Requests badge is a deeper brick (`A84A35`) instead of terracotta. "Women only" badge, FAB (brown label on coral) and selected nav indicator (coral) fine. Dark: secondary lines readable, coral FAB/badge. | Fixed |
| `40_meal_detail_open` | Restaurant address and the host bio were invisible: readable. Restaurant card has shadow. "Request to join" is now the coral primary (was a pale slab that looked disabled). | Fixed |
| `52_requests_data` | Approve is the coral primary, Deny is an outlined button with a brick label (`dangerText`), both 48 px+ and side by side (before: Approve was a bare text link, Deny pale terracotta). Cards separated by shadow. Disabled Approve (meal passed) reads as disabled. Tab badge is brick with a cream count. | Fixed (see D3) |
| `63_chat_messages` | Timestamps and "Seen" were invisible: readable. Own bubbles are now a defined peach with brown text (was a coral block); the other party's bubble is the card surface. Safety-tips bullets are visible, the card has a shadow. Message bubbles were left flat on purpose: the peach/surface step plus left/right alignment separates them, and a shadow on every bubble would clutter the thread (comment in `message_bubble.dart`). | Fixed (see D4) |
| `83_settings` | Section headers (Legal, Account, About) and the version line were invisible: readable. "Delete account" is brick red instead of pale terracotta. | Fixed |
| `93_discover_error` | Error text is brick (`dangerText`), readable on cream. Still no retry action. | Text fixed, behaviour is D1 |
| `37_create_meal_in_flight` (spinner) | The submit button keeps its coral fill and shows a dark spinner (before: grey button, white spinner almost invisible). | Fixed |
| Dark `22`, `52`, `63` | Same fixes, surface/bg step is small (~1.1:1) but text, buttons and bubbles are legible; the shadow is not visible on dark, the surface step carries it. | OK |

## Remaining defects (not 16a scope)

| # | Defect | Severity | Owner |
|---|---|---|---|
| D1 | Error states are a bare line of text: no retry button, no icon, no shared widget (`93`, `91`, `92`, `90`) | P1 | 16b (shared widgets) |
| D2 | Sign-in "Phone number" floating label overlaps the top edge of the field; the "or" divider lines are very faint (decorative `divider` token) | P3 | 17 (onboarding) |
| D3 | Requests: "Meal time has passed" chip (`errorContainer`) is low-emphasis pink on the peach card; no "which meal" headline hierarchy | P2 | 18 (requests) |
| D4 | Chat: the message list is clipped under the safety card (text cut at the card's lower edge, `63`); the composer bar is not recognisable as an input; own vs other bubble differ only by a peach step | P2 | 18 (chat) |
| D5 | Discover: the Paris notice has the same surface as the meal cards (no hierarchy); the FAB covers the card content when scrolled | P2 | 17 (Discover) |
| D6 | Meal detail: sparse layout: a lot of empty page below the single "Request to join" button | P2 | 17 (meal detail) |
| D7 | Settings: still a short plain list (Legal, Account, About), see AUDIT owner ask 4 | P2 | 18 (settings) |
| D8 | Dates are long ("October 6, 2026 at 8:30 PM"), no relative form; router resets on any user-doc change (X-09) | P2 | 16b (dates/router) |
| D9 | Large text (xxl) overflows and keyboard-obscured actions (X-10) were not re-captured here | P1 | 16b / 17 / 18 per screen |

Nothing found that belongs to 16a's scope (theme, tokens, buttons, font, shadow) and is still open. The add-photo tile outline (carry-in) was fixed in this task: `wp.muted` 1 px border, test-guarded.

## What is test-guarded (see `docs/TEST-PLAN.md`)

Contrast of every text/background pair above, button states and spinner contrast, no border/divider token used as text, container roles, Nunito on every style and its asset weights, card shadow wiring, the add-photo outline. What is NOT test-guarded: how it looks (this document), and the xxl text size.
