# Convyve — one-command targets. See docs/WORKFLOWS.md for the wider process.

# firebase-tools' emulators require Java 21+ on PATH. macOS ships no `java`
# by default; if only an older Homebrew openjdk keg is linked (this repo's
# dev machine had openjdk@17), prefer the (keg-only, unlinked) `openjdk`
# formula's bin dir without touching the user's shell rc / global PATH.
# No-op if `brew`/`openjdk` aren't present — CI images should ship Java 21+
# directly.
OPENJDK_PREFIX := $(shell brew --prefix openjdk 2>/dev/null)
ifneq ($(OPENJDK_PREFIX),)
export PATH := $(OPENJDK_PREFIX)/bin:$(PATH)
endif

# Overridable: pass a specific simulator id/name from CI, e.g.
#   make e2e DEVICE=<udid>
# Defaults to a device *name* (Flutter matches by substring), not a fixed
# udid, since simulator udids differ per machine. The device must already
# be booted (see `ios-sim-boot` below) — `flutter test -d <name>` targets a
# running simulator, it doesn't boot one itself.
#
# Dedicated to this project: "Convyve E2E" is a project-specific simulator
# (not the generic "iPhone 17 Pro" one other local projects' agents may run
# concurrently on the same machine) — sharing a simulator across concurrent,
# unrelated `flutter run`/`flutter test` sessions causes severe resource
# contention and flaky/hung runs (confirmed live: a standalone `chat_test.dart`
# run hung for 12+ minutes while another project's agent was running on the
# same "iPhone 17 Pro" device). Create it once with:
#   xcrun simctl create "Convyve E2E" <iPhone-17-Pro devicetype id> <latest iOS runtime id>
# (ids from `xcrun simctl list devicetypes` / `xcrun simctl list runtimes`).
# `ios-sim-boot` below boots it if needed, same as any other $(DEVICE).
DEVICE ?= Convyve E2E

# Unflavored `Runner` scheme's bundle id (see ios/Runner.xcodeproj — the
# "prod"/"stage" schemes use different, flavor-suffixed ids; `flutter test
# integration_test` with no --flavor builds the unflavored config).
BUNDLE_ID ?= com.daki.noteatalone.notEatAlone

# ios/Runner/GoogleService-Info.plist is gitignored (per-flavor plists live
# under ios/config/{prod,stage}/ and are copied in at build time by
# ios/scripts/copy_firebase_plist.sh into the *built app bundle*). Xcode's
# own "Copy Bundle Resources" phase additionally references the literal
# ios/Runner/GoogleService-Info.plist file as a project resource, though,
# so the *source* file must exist on disk before that phase runs or the
# build fails outright on a clean checkout. `flutter test integration_test`
# (no --flavor) builds the unflavored config, which the copy script's
# default branch treats as "prod" — so we seed the same file here.
# Idempotent: only copies when the destination is missing.
.PHONY: ios-plist
ios-plist:
	@if [ ! -f ios/Runner/GoogleService-Info.plist ]; then \
		echo "[ios-plist] copying ios/config/prod/GoogleService-Info.plist -> ios/Runner/"; \
		cp ios/config/prod/GoogleService-Info.plist ios/Runner/GoogleService-Info.plist; \
	fi

# Boots the default $(DEVICE) simulator if it isn't already booted.
# Idempotent: `simctl boot` on an already-booted device errors, so we
# probe `simctl list` first rather than relying on boot's own exit code.
.PHONY: ios-sim-boot
ios-sim-boot:
	@udid=$$(xcrun simctl list devices available | awk -F '[()]' -v name="$(DEVICE)" '$$0 ~ name && !/unavailable/ {print $$2; exit}'); \
	if [ -z "$$udid" ]; then \
		echo "error: no available simulator matching '$(DEVICE)' (see: xcrun simctl list devices available)"; \
		exit 1; \
	fi; \
	if ! xcrun simctl list devices | grep "$$udid" | grep -q Booted; then \
		echo "[ios-sim-boot] booting $(DEVICE) ($$udid)"; \
		xcrun simctl boot "$$udid"; \
		xcrun simctl bootstatus "$$udid" -b; \
	fi

# `not_eat_alone`'s Info.plist declares NSLocationWhenInUseUsageDescription,
# so the FIRST location request of a run shows a real, blocking native iOS
# permission alert (Allow Once / Allow While Using App / Don't Allow) — a
# UIKit alert, not a Flutter widget, so `tester.pumpAndSettle()` never
# dismisses it. Nothing taps it in an unattended run, so
# `LocationService.currentOrParis()`'s `_requestPermission()` future never
# resolves, `locationProvider` never resolves, and `DiscoveryScreen` is
# stuck rendering its `CircularProgressIndicator` — whose animation ticker
# keeps scheduling frames forever, hanging `pumpAndSettle()` indefinitely
# (confirmed live: the app had actually already reached Discover — the
# smoke test's own marker was on screen — underneath the dialog; see
# task-3-report.md). `simctl privacy ... revoke location` pre-decides the OS
# permission prompt before the app ever asks, so it's never shown; `revoke`
# (not `grant`) is deliberate — it drives `LocationService` down its
# already-tested denied -> Paris-fallback path deterministically, so the
# smoke test doesn't depend on the simulator's (unset) simulated location.
# Idempotent: `simctl privacy` just re-applies the same decision.
.PHONY: ios-privacy
ios-privacy: ios-sim-boot
	@udid=$$(xcrun simctl list devices available | awk -F '[()]' -v name="$(DEVICE)" '$$0 ~ name && !/unavailable/ {print $$2; exit}'); \
	xcrun simctl privacy "$$udid" revoke location $(BUNDLE_ID)

# Runs the live end-to-end smoke test (and, as more integration_test/*_test.dart
# scenarios are added, the whole suite) against the real Firebase Emulator
# Suite on a booted iOS Simulator. The simulator shares the host network, so
# it reaches the emulators at 127.0.0.1 (matching EmulatorConfig.local()) —
# an Android emulator would need 10.0.2.2 instead and isn't wired here.
#
# `ios-privacy`'s pre-build revoke isn't reliable on its own: `flutter test`
# reinstalls the app fresh every run, and that reinstall can reset the
# simulator's per-app privacy decision made before the (re)install — so the
# location alert can still appear (confirmed live: intermittent — passed
# clean in one run, needed a second revoke mid-run in another; see
# task-3-report.md). A revoke call also dismisses an *already-showing*
# alert immediately (also confirmed live), so a background loop re-applying
# it every 2s for the run's duration is a robust belt-and-suspenders fix:
# idempotent, and guaranteed to land within 2s of any alert appearing,
# well inside the smoke test's 20s bounded pump loop.
# `--only firestore` (unqualified) makes firebase-tools' emulator controller
# select EVERY database entry in firebase.json's `firestore` array
# ((default) + stage — see firebase.json) via its internal
# `getFirestoreConfig()`; when more than one entry comes back, the Firestore
# emulator logs "does not support multiple databases yet" and silently
# starts with OPEN rules (no enforcement at all) instead of loading
# firebase/firestore.rules — confirmed live: `firebase emulators:exec --only
# firestore ...` prints exactly that warning, and an unauthenticated REST
# write against the emulator then succeeds. `firestore:(default)` scopes
# `--only` to just the `(default)` database entry (the one the app's E2E
# flavor — Flavor.prod, firestoreDatabaseId '(default)' — connects to), so
# getFirestoreConfig() returns a single-element array and the emulator loads
# and enforces firebase/firestore.rules normally (confirmed live: the same
# REST write then returns 403 PERMISSION_DENIED). This does NOT affect
# `firebase deploy` — deploy's `--only firestore` (no colon) is unchanged and
# still resolves to `allDatabases = true`, deploying rules to both
# `(default)` and `stage` (verified against both firebase-tools 15.24 and
# the CI-pinned firebase-tools@13 line: identical selection logic in
# lib/firestore/fsConfig.js on both).
.PHONY: e2e
e2e: ios-plist ios-sim-boot ios-privacy
	cd firebase/functions && npm ci && npm run build
	@udid=$$(xcrun simctl list devices available | awk -F '[()]' -v name="$(DEVICE)" '$$0 ~ name && !/unavailable/ {print $$2; exit}'); \
	( while true; do sleep 2; xcrun simctl privacy "$$udid" revoke location $(BUNDLE_ID) >/dev/null 2>&1; done ) & \
	watchdog=$$!; \
	firebase emulators:exec --only "auth,firestore:(default),functions,storage" \
		--project not-eat-alone \
		"fvm flutter test integration_test -d '$(DEVICE)'"; \
	status=$$?; \
	kill $$watchdog >/dev/null 2>&1; \
	exit $$status
