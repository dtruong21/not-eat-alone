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
rm -f "$HANDOFF_DIR"/*.ready "$HANDOFF_DIR"/*.ack "$HANDOFF_DIR"/.done "$HANDOFF_DIR"/.host-up

FAILED=0
pids=()
cleanup() {
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
  for ready in "$HANDOFF_DIR"/*.ready; do
    [[ -e "$ready" ]] || continue
    name="$(basename "$ready" .ready)"
    [[ -e "$HANDOFF_DIR/$name.ack" ]] && continue
    # A short settle so the last frame is on screen before the grab.
    sleep 0.4
    rm -f "$OUT_DIR/$name.png"
    if xcrun simctl io "$UDID" screenshot --type=png "$OUT_DIR/$name.png" >/dev/null 2>&1 \
        && [[ -s "$OUT_DIR/$name.png" ]]; then
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
