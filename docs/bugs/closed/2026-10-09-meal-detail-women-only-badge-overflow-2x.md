## [P3] Meal detail restaurant card: name row overflows by 48px with "Women only" badge at 2.0x text scale on a 320dp-wide screen

**Repro:**
1. Open the detail of a women-only meal (viewer any gender) on a 320dp-wide device (or widget test `Size(320, 640)`, DPR 1).
2. Set system font scale to 2.0x (Android max / iOS accessibility sizes).
3. Look at the restaurant card header row (restaurant name + badge), with a long restaurant name.

**Expected:** Badge wraps/shrinks or the name ellipsizes/wraps; no overflow (DESIGN: layouts must hold up to at least 1.5x; 2.0x is the extended bar for the new "Open in Maps" row).
**Actual:** `A RenderFlex overflowed by 48 pixels on the right` from the `Row` at `lib/features/meal/presentation/meal_detail_screen.dart:86` (Expanded name + `_WomenOnlyBadge`); in release the badge is clipped. 1.5x on the same screen is fine. The overflow is pre-existing and independent of the Open in Maps button (the button itself lays out correctly at 2.0x, with or without the badge).

**Device/OS:** flutter_test widget harness (320x640 @1x, textScaler 2.0, light). Not seen on a device.
**Build:** develop @ 5fafd77
**Frequency:** always under those conditions.

**Hypothesis:** `_WomenOnlyBadge` has a non-flexible fixed padding + unconstrained Text; at 2.0x the badge's intrinsic width exceeds the row once `Expanded` has shrunk the name to its minimum. Wrap the badge in `Flexible` or move it below the name when `MediaQuery.textScalerOf(context)` is large.

**Status:** Fixed — `_RestaurantHeader` stacks the badge below the name above 1.5x text scale (side by side at normal sizes); 2.0x/320dp/long-name case added to `meal_detail_open_in_maps_edge_test.dart`.
