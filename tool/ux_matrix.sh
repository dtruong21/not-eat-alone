#!/usr/bin/env bash
# Runs the whole UX capture matrix (docs/superpowers/specs/
# 2026-10-05-ux-pass-design.md §2.1): 2 simulators x {light, dark} x
# {default text, large accessibility text} = 8 `make ux-capture` runs.
# Dev tooling, not part of CI.
#
#   tool/ux_matrix.sh                  # all 8 cells (about 5 min each)
#   tool/ux_matrix.sh --only se3-dark  # only cells whose name contains this
#   tool/ux_matrix.sh --verify         # only check ux_audit/out (no capture)
#
# Output: ux_audit/out/<device>-<theme>-<size>/NN_*.png, logs in
# ux_audit/out/logs/<cell>.log. Devices:
#   iphone17  "Convyve E2E" (iPhone 17 Pro class, 402x874 pt)
#   se3       "Convyve UX Small" (iPhone SE 3rd gen, 375x667 pt), created here
#             on first use with the SAME iOS runtime as "Convyve E2E"
# Only these two simulators are touched; never the generic "iPhone 17 Pro".
#
# The appearance and content size of both simulators are changed per cell and
# restored to what they were when the script started, on exit, Ctrl-C and
# SIGTERM alike (a simulator this script booted is shut down again).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUT="$ROOT/ux_audit/out"
LOGS="$OUT/logs"

E2E_NAME="Convyve E2E"
SMALL_NAME="Convyve UX Small"
SMALL_TYPE_NAME="iPhone SE (3rd generation)"
LARGE_TEXT="accessibility-extra-large"
# A real screenshot of this app is far above this; a blank one is not.
MIN_PNG_BYTES=15000

ONLY=""
VERIFY_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) ONLY="${2:?--only needs a value}"; shift 2 ;;
    --verify) VERIFY_ONLY=1; shift ;;
    *) echo "usage: $0 [--only <substring>] [--verify]" >&2; exit 2 ;;
  esac
done

# --- verification (equal counts, no blank PNGs) -----------------------------
# Every cell must hold the same screenshots, except where a step failed in that
# cell (a state that cannot be produced at, say, a large text size) and the
# run log says so (`UXSTEP FAIL <name>` in <cell>.findings.txt). Anything else
# missing, and any PNG below MIN_PNG_BYTES (a blank screen is far smaller), is
# a problem.
verify() {
  local bad=0 dirs=() d cell n small f m base
  for d in "$OUT"/*-{light,dark}-{default,xxl}; do
    [[ -d "$d" ]] || continue
    # Leftover of an interrupted run.
    if [[ -z "$(ls -A "$d" 2>/dev/null)" ]]; then rmdir "$d"; continue; fi
    [[ -n "$ONLY" && "$(basename "$d")" != *"$ONLY"* ]] && continue
    dirs+=("$d")
  done
  if [[ ${#dirs[@]} -eq 0 ]]; then echo "[ux-matrix] nothing to verify"; return 1; fi
  local all
  all="$(for d in "${dirs[@]}"; do (cd "$d" && ls *.png); done | sort -u)"
  local total
  total="$(echo "$all" | wc -l | tr -d ' ')"
  for d in "${dirs[@]}"; do
    cell="$(basename "$d")"
    n=$(find "$d" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')
    small=0
    while IFS= read -r f; do
      if [[ $(stat -f %z "$f") -lt $MIN_PNG_BYTES ]]; then
        echo "[ux-matrix] SUSPECT (blank?) $f ($(stat -f %z "$f") bytes)"
        small=$((small + 1))
      fi
    done < <(find "$d" -maxdepth 1 -name '*.png')
    printf '[ux-matrix] %-26s %3s of %s png, %s small\n' "$cell" "$n" "$total" "$small"
    [[ $small -ne 0 ]] && bad=1
    for m in $(comm -23 <(echo "$all") <(cd "$d" && ls *.png | sort)); do
      base="${m%.png}"
      if grep -q "UXSTEP FAIL $base:" "$LOGS/$cell.findings.txt" 2>/dev/null; then
        echo "[ux-matrix]   missing $m (explained: its step failed in this cell)"
      else
        echo "[ux-matrix]   MISSING $m (not explained by the log)"
        bad=1
      fi
    done
  done
  [[ $bad -eq 0 ]] && echo "[ux-matrix] verify OK: ${#dirs[@]} cells, $total distinct screenshots"
  return $bad
}

if [[ $VERIFY_ONLY -eq 1 ]]; then verify; exit $?; fi

# --- simulators --------------------------------------------------------------
udid_of() {
  xcrun simctl list devices available \
    | awk -F '[()]' -v name="$1" '$0 ~ name && !/unavailable/ {print $2; exit}'
}

E2E_UDID="$(udid_of "$E2E_NAME")"
if [[ -z "$E2E_UDID" ]]; then
  echo "[ux-matrix] simulator '$E2E_NAME' not found (see Makefile DEVICE comment)" >&2
  exit 1
fi

# The runtime "Convyve E2E" runs on, so both devices render the same iOS.
RUNTIME="$(xcrun simctl list devices available -j | python3 -c "
import json, sys
udid = sys.argv[1]
for runtime, devices in json.load(sys.stdin)['devices'].items():
    if any(d['udid'] == udid for d in devices):
        print(runtime)
        break
" "$E2E_UDID")"
if [[ -z "$RUNTIME" ]]; then echo "[ux-matrix] cannot find the runtime of $E2E_NAME" >&2; exit 1; fi

SMALL_UDID="$(udid_of "$SMALL_NAME")"
if [[ -z "$SMALL_UDID" ]]; then
  TYPE_ID="$(xcrun simctl list devicetypes -j | python3 -c "
import json, sys
for t in json.load(sys.stdin)['devicetypes']:
    if t['name'] == sys.argv[1]:
        print(t['identifier'])
        break
" "$SMALL_TYPE_NAME")"
  if [[ -z "$TYPE_ID" ]]; then echo "[ux-matrix] no device type '$SMALL_TYPE_NAME'" >&2; exit 1; fi
  echo "[ux-matrix] creating '$SMALL_NAME' ($TYPE_ID, $RUNTIME)"
  SMALL_UDID="$(xcrun simctl create "$SMALL_NAME" "$TYPE_ID" "$RUNTIME")"
fi

is_booted() { xcrun simctl list devices | grep "$1" | grep -q Booted; }

E2E_APP=""; E2E_SIZE=""; E2E_BOOTED=1
SMALL_APP=""; SMALL_SIZE=""; SMALL_BOOTED=1
restore_one() { # <udid> <app> <size> <was_booted>
  # An empty app/size means "not captured yet": leave that simulator alone.
  [[ -n "$2" ]] && xcrun simctl ui "$1" appearance "$2" >/dev/null 2>&1
  [[ -n "$3" ]] && xcrun simctl ui "$1" content_size "$3" >/dev/null 2>&1
  [[ "$4" == 0 ]] && xcrun simctl shutdown "$1" >/dev/null 2>&1
  return 0
}
restore() {
  trap - EXIT INT TERM
  echo "[ux-matrix] restoring simulator appearance / text size"
  restore_one "$E2E_UDID" "$E2E_APP" "$E2E_SIZE" "$E2E_BOOTED"
  restore_one "$SMALL_UDID" "$SMALL_APP" "$SMALL_SIZE" "$SMALL_BOOTED"
}
# Installed BEFORE anything is booted or changed.
trap restore EXIT
trap 'echo "[ux-matrix] interrupted"; exit 130' INT TERM

# Remember each simulator's state so the end of the run can put it back
# (macOS ships bash 3.2: no associative arrays, hence the two variable sets).
prepare() { # <prefix> <udid>
  local p="$1" u="$2" booted=0 app size
  if is_booted "$u"; then booted=1; else
    xcrun simctl boot "$u" && xcrun simctl bootstatus "$u" -b >/dev/null
  fi
  app="$(xcrun simctl ui "$u" appearance 2>/dev/null | tr -d '[:space:]')"
  size="$(xcrun simctl ui "$u" content_size 2>/dev/null | tr -d '[:space:]')"
  case "$app" in light|dark) ;; *) app=light ;; esac
  [[ -z "$size" || "$size" == unsupported || "$size" == unknown ]] && size=large
  eval "${p}_BOOTED=$booted ${p}_APP=$app ${p}_SIZE=$size"
}

prepare E2E "$E2E_UDID"
prepare SMALL "$SMALL_UDID"

# --- the matrix --------------------------------------------------------------
mkdir -p "$LOGS"
FAILED=()
cells=0
for dev in iphone17 se3; do
  if [[ "$dev" == iphone17 ]]; then NAME="$E2E_NAME"; UDID="$E2E_UDID"; else NAME="$SMALL_NAME"; UDID="$SMALL_UDID"; fi
  for theme in light dark; do
    for size in default xxl; do
      cell="$dev-$theme-$size"
      [[ -n "$ONLY" && "$cell" != *"$ONLY"* ]] && continue
      cells=$((cells + 1))
      # iOS' own default text size is "large".
      text="large"; [[ "$size" == xxl ]] && text="$LARGE_TEXT"
      xcrun simctl ui "$UDID" appearance "$theme"
      xcrun simctl ui "$UDID" content_size "$text"
      rm -rf "$OUT/$cell"
      echo "[ux-matrix] === $cell ($NAME, $theme, text=$text) $(date +%H:%M:%S)"
      if make ux-capture DEVICE="$NAME" OUT="$cell" >"$LOGS/$cell.log" 2>&1; then
        echo "[ux-matrix] $cell ok: $(find "$OUT/$cell" -name '*.png' | wc -l | tr -d ' ') png"
      elif grep -q '^flutter: UXSUMMARY' "$LOGS/$cell.log"; then
        # The run reached its end; only steps failed (listed in findings).
        echo "[ux-matrix] $cell done with failed steps: $(find "$OUT/$cell" -name '*.png' | wc -l | tr -d ' ') png"
      else
        echo "[ux-matrix] $cell FAILED (see $LOGS/$cell.log)"
        FAILED+=("$cell")
      fi
      grep -hE "UXSTEP FAIL|UXOVERFLOW" "$LOGS/$cell.log" | sed 's/^flutter: //' | sort -u > "$LOGS/$cell.findings.txt"
    done
  done
done

[[ $cells -eq 0 ]] && { echo "[ux-matrix] no cell matches '$ONLY'" >&2; exit 2; }
verify || FAILED+=("verify")
if [[ ${#FAILED[@]} -gt 0 ]]; then echo "[ux-matrix] problems: ${FAILED[*]}"; exit 1; fi
echo "[ux-matrix] all $cells cells captured"
