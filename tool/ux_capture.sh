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
# It exits when /tmp/convyve-ux/.done appears (the Makefile touches it after
# the test process ends) or on SIGTERM/SIGINT, killing its children.
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
rm -f "$HANDOFF_DIR"/*.ready "$HANDOFF_DIR"/*.ack "$HANDOFF_DIR"/.done

pids=()
cleanup() {
  for p in "${pids[@]:-}"; do
    [[ -n "$p" ]] && kill "$p" >/dev/null 2>&1
  done
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# Avatars: generate (idempotent) + serve on 127.0.0.1:8765.
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

echo "[ux-capture] device=$UDID out=$OUT_DIR handoff=$HANDOFF_DIR"
while [[ ! -f "$HANDOFF_DIR/.done" ]]; do
  for ready in "$HANDOFF_DIR"/*.ready; do
    [[ -e "$ready" ]] || continue
    name="$(basename "$ready" .ready)"
    [[ -e "$HANDOFF_DIR/$name.ack" ]] && continue
    # A short settle so the last frame is on screen before the grab.
    sleep 0.4
    if xcrun simctl io "$UDID" screenshot --type=png "$OUT_DIR/$name.png" >/dev/null 2>&1; then
      echo "[ux-capture] shot $name"
    else
      echo "[ux-capture] screenshot FAILED for $name" >&2
    fi
    # Ack even on failure so the test never stalls; the missing PNG is the signal.
    : >"$HANDOFF_DIR/$name.ack"
  done
  sleep 0.2
done
echo "[ux-capture] done"
