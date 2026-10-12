## [P2] Icon-only controls on the core flow have no accessible name (rating stars, chat send, Paris notice close, add-photo tile)

**Repro (widget semantics test, no device needed):**
1. Pump `MessageComposer`, `ParisNotice`, the rating sheet and the profile form.
2. Read the semantics of `message_composer_send_button`, `paris_notice_close_button`, `rating_star_1..5`.

**Expected:** (universal edge case 13, "TalkBack/VoiceOver reaches every interactive element ... semantic labels present") each control announces a name ("Send message", "Dismiss notice", "1 star" ... "5 stars" with selected state, "Add photo").
**Actual:** All are `IconButton`/`InkWell` with only an icon and no `tooltip`/`Semantics`/`semanticLabel`: the label and tooltip are empty, so a screen reader says just "button". A blind user cannot tell the send button from anything else, cannot rate (five unnamed buttons, selection not announced) and cannot dismiss the notice. The notice close button is also only 24 dp (`constraints` of `WarmPlayfulSpacing.s5`, `padding: zero`), below the 48 dp target; the add-photo tile is an `InkWell` around an icon with no label. Buttons that do have names (`Settings`, `Sign out`, `Can't make it`) show the harness is sound.

**Verified by test:** `test/core/a11y/icon_only_controls_semantics_edge_test.dart` (harness case with a tooltip passes; the three real cases are skipped until fixed). Actual TalkBack/VoiceOver pass NOT VERIFIED (no device).

**Device/OS:** flutter_test semantics tree; applies to iOS and Android.
**Build:** develop @ 979e5f2
**Frequency:** always.

**Hypothesis:** add `tooltip:` (or `Semantics(label:, button: true, selected:)`) to each; give stars a label like `'$i star${i == 1 ? '' : 's'}'` with `selected: i <= _stars`; raise the notice close target to 48 dp.
