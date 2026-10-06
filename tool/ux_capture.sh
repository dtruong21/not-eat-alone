#!/usr/bin/env bash
# Host side of the UX screenshot capture harness (see docs/superpowers/specs/
# 2026-10-05-ux-pass-design.md §2.1). Dev tooling, not part of CI.
#
#   tool/ux_capture.sh <simulator-name-or-udid> <out-subdir>
#
# The capture test (ux_audit/capture_test.dart) runs inside the iOS Simulator
# and writes /tmp/convyve-ux/<name>.ready whenever the screen is ready to be
# photographed. This script polls for those files, runs
# `xcrun simctl io <udid> screenshot ux_audit/out/<out-subdir>/<name>.png`,
# then writes <name>.ack so the test carries on. It also
#   - serves the placeholder avatars (tool/ux_images.py) on 127.0.0.1:8765, and
#   - executes host commands from the test (`cmd.*.req` files): freeze/thaw
#     (SIGSTOP/SIGCONT) of this project's Firestore emulator or of the
#     firebase-tools process hosting the Auth emulator, so an action that
#     waits on a server stays "in flight" while the screen is photographed
#     (a 25 s watchdog and the exit trap thaw; only a process that is the
#     single match for this project is touched), and
#   - re-applies `simctl privacy ... revoke location` every 2 s (same
#     belt-and-suspenders as `make e2e`: a native location alert would block
#     the app, and nothing taps it in an unattended run).
# It touches /tmp/convyve-ux/.host-up once the avatar server answers (the
# Makefile waits for it before starting the test), and exits when
#   - /tmp/convyve-ux/.done appears (the Makefile touches it after the test), or
#   - UX_PARENT_PID (the Makefile's recipe shell) dies, or
#   - UX_MAX_SECONDS (default 1500) elapse, so it can never outlive a run
# (a background job of a non-interactive sh starts with SIGINT ignored, so a
# Ctrl-C on make cannot be relied on to reach it). Exit status is non-zero if
# any screenshot failed or came out empty. Children (image server, watchdog)
# are always killed on exit.
set -u

DEVICE="${1:?usage: ux_capture.sh <simulator-name-or-udid> <out-subdir>}"
OUT_SUBDIR="${2:?usage: ux_capture.sh <simulator-name-or-udid> <out-subdir>}"
BUNDLE_ID="${BUNDLE_ID:-com.daki.noteatalone.notEatAlone}"
HANDOFF_DIR="${HANDOFF_DIR:-/tmp/convyve-ux}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/ux_audit/out/$OUT_SUBDIR"

# Resolve a name to a udid (a udid passes straight through).
if [[ "$DEVICE" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
  UDID="$DEVICE"
else
  UDID="$(xcrun simctl list devices available \
    | awk -F '[()]' -v name="$DEVICE" '$0 ~ name && !/unavailable/ {print $2; exit}')"
fi
if [[ -z "$UDID" ]]; then
  echo "[ux-capture] no available simulator matching '$DEVICE'" >&2
  exit 1
fi

mkdir -p "$OUT_DIR" "$HANDOFF_DIR"
rm -f "$HANDOFF_DIR"/*.ready "$HANDOFF_DIR"/*.ack "$HANDOFF_DIR"/cmd.*.req "$HANDOFF_DIR"/.done "$HANDOFF_DIR"/.host-up

FAILED=0
# Processes this script may freeze (SIGSTOP) for the test, selected by command
# line and always scoped to THIS project's id; a pattern must match exactly one
# process, otherwise nothing is signalled (never another project's emulators).
FS_PATTERN='cloud-firestore-emulator.*project_id not-eat-alone'
AUTH_PATTERN='bin/firebase emulators:exec.*project not-eat-alone'
pids=()

# freeze_proc <label> <pattern>: SIGSTOP the single matching process and start
# a watchdog that SIGCONTs it after 25 s, independent of the main loop.
freeze_proc() {
  local label="$1" pattern="$2" count
  count="$(pgrep -f "$pattern" | wc -l | tr -d ' ')"
  if [[ "$count" != 1 ]]; then
    echo "[ux-capture] NOT freezing $label: $count processes match (need exactly 1)" >&2
    return 0
  fi
  pkill -STOP -f "$pattern"
  ( sleep 25; pkill -CONT -f "$pattern" ) >/dev/null 2>&1 &
  pids+=($!)
}

# thaw_proc <label> <pattern>: SIGCONT (a no-op on a running process).
thaw_proc() {
  [[ "$(pgrep -f "$2" | wc -l | tr -d ' ')" == 1 ]] && pkill -CONT -f "$2"
  return 0
}
cleanup() {
  # Never leave an emulator stopped (SIGCONT on a running process is a no-op).
  pkill -CONT -f "$FS_PATTERN" >/dev/null 2>&1
  pkill -CONT -f "$AUTH_PATTERN" >/dev/null 2>&1
  for p in "${pids[@]:-}"; do
    [[ -n "$p" ]] && kill "$p" >/dev/null 2>&1
  done
}
trap cleanup EXIT
trap 'FAILED=1; exit 130' INT TERM

MAX_SECONDS="${UX_MAX_SECONDS:-1500}"
PARENT_PID="${UX_PARENT_PID:-}"

# Avatars: serve on 127.0.0.1:8765 (binds first, generates while serving).
python3 "$ROOT/tool/ux_images.py" >"$HANDOFF_DIR/images.log" 2>&1 &
pids+=($!)

# Location-permission watchdog (see header).
(
  while true; do
    sleep 2
    xcrun simctl privacy "$UDID" revoke location "$BUNDLE_ID" >/dev/null 2>&1
  done
) &
pids+=($!)

# Wait (bounded) until the LAST avatar is served, so no avatar request can race
# generation; only then tell the Makefile the test may start.
up=0
for _ in $(seq 1 120); do
  if curl -sf -o /dev/null "http://127.0.0.1:8765/lea.png"; then up=1; break; fi
  sleep 0.5
done
if [[ "$up" -ne 1 ]]; then
  echo "[ux-capture] avatar server did not come up on :8765 (see $HANDOFF_DIR/images.log)" >&2
  exit 1
fi
: >"$HANDOFF_DIR/.host-up"

echo "[ux-capture] device=$UDID out=$OUT_DIR handoff=$HANDOFF_DIR"
while [[ ! -f "$HANDOFF_DIR/.done" ]]; do
  if [[ -n "$PARENT_PID" ]] && ! kill -0 "$PARENT_PID" 2>/dev/null; then
    echo "[ux-capture] parent $PARENT_PID is gone; exiting" >&2
    exit 1
  fi
  if (( SECONDS > MAX_SECONDS )); then
    echo "[ux-capture] max lifetime ${MAX_SECONDS}s exceeded; exiting" >&2
    exit 1
  fi
  # Host commands from the test (see hostCommand in support/handoff.dart).
  for req in "$HANDOFF_DIR"/cmd.*.req; do
    [[ -e "$req" ]] || continue
    ack="${req%.req}.ack"
    [[ -e "$ack" ]] && continue
    case "$(cat "$req" 2>/dev/null)" in
      freeze-firestore) freeze_proc firestore "$FS_PATTERN" ;;
      thaw-firestore)   thaw_proc firestore "$FS_PATTERN" ;;
      freeze-auth)      freeze_proc auth "$AUTH_PATTERN" ;;
      thaw-auth)        thaw_proc auth "$AUTH_PATTERN" ;;
      *) echo "[ux-capture] unknown command in $req" >&2 ;;
    esac
    : >"$ack"
  done
  for ready in "$HANDOFF_DIR"/*.ready; do
    [[ -e "$ready" ]] || continue
    name="$(basename "$ready" .ready)"
    [[ -e "$HANDOFF_DIR/$name.ack" ]] && continue
    # A short settle so the last frame is on screen before the grab.
    sleep 0.4
    rm -f "$OUT_DIR/$name.png"
    # The grab runs in the background so a hung simctl cannot stall the loop
    # (and with it the thaw of a frozen emulator): killed after 15 s.
    xcrun simctl io "$UDID" screenshot --type=png "$OUT_DIR/$name.png" >/dev/null 2>&1 &
    shot_pid=$!
    for _ in $(seq 1 150); do
      kill -0 "$shot_pid" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "$shot_pid" 2>/dev/null; then
      kill "$shot_pid" 2>/dev/null
      wait "$shot_pid" 2>/dev/null
      echo "[ux-capture] screenshot call timed out for $name" >&2
      FAILED=1
      rm -f "$OUT_DIR/$name.png"
    elif wait "$shot_pid" && [[ -s "$OUT_DIR/$name.png" ]]; then
      echo "[ux-capture] shot $name"
    else
      echo "[ux-capture] screenshot FAILED for $name" >&2
      FAILED=1
    fi
    # Ack even on failure so the test never stalls; FAILED makes the exit
    # status non-zero.
    : >"$HANDOFF_DIR/$name.ack"
  done
  sleep 0.2
done
echo "[ux-capture] done"
exit "$FAILED"
