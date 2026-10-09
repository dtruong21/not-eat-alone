## [P2] Sign-in buttons overflow at 1.5x text; rating and report sheets overflow with the keyboard; age gate and sheets overflow at 2.0x

**Repro:**
1. Phone 360dp wide, system font scale 1.5x, light or dark: open the sign-in screen.
2. 360x640 phone (1.0x): open the rating sheet (post-meal card -> Rate) or the report sheet (chat/meal detail -> Report) and tap the comment/note field so the keyboard opens.
3. Font scale 2.0x (Android maximum): open sign-in, the age gate, the rating sheet.

**Expected:** No overflow up to 1.5x (DESIGN) and graceful behaviour at 2.0x; sheets scroll when the keyboard covers them.
**Actual (real Nunito font, widget harness):**
- Sign-in, 1.5x: `signin_screen.dart:249` (the `Row` of icon + label in `_AuthButton`) overflows by 5.5px on the right; at 2.0x by 69-87px (label clipped on "Continue with Google/Apple" and "Send code").
- Rating sheet (`rating_sheet.dart` ~L99) and report sheet (`report_sheet.dart` ~L115) are non-scrolling `Column`s inside a modal sheet: keyboard open, 360x640 1.0x overflows by 81px (rating) and 122px (report); 360x800 at 1.5x with keyboard by 16px (rating) and 47px (report), hiding the field/Submit button.
- 2.0x full-suite sweep also flags `age_gate_screen.dart:144` (vertical overflow) and the rating sheet (66px).

**Device/OS:** flutter_test harness, Nunito loaded, 360x640 and 360x800 @1x. Not seen on hardware.
**Build:** develop @ 8cf1b41
**Frequency:** always under those conditions.

**Hypothesis:** `_AuthButton`: wrap the label in `Flexible` (or `FittedBox`/two-line label) and drop fixed horizontal padding. Sheets: wrap the content in `SingleChildScrollView` (keep the viewInsets padding) and use `useSafeArea: true`. Age gate: scroll body.

**Regression tests:** `test/features/auth/presentation/signin_screen_text_scale_edge_test.dart` (1.5x cases skipped) and `test/features/safety/presentation/sheets_keyboard_edge_test.dart` (keyboard/1.5x cases skipped via `bug = true`).
