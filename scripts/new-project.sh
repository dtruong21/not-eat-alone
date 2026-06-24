#!/usr/bin/env bash
# new-project.sh — bootstrap a fresh project from a chosen template stack.
#
# Usage:
#   ./scripts/new-project.sh react-native ~/Documents/my-new-app
#   ./scripts/new-project.sh flutter      ~/Documents/my-new-app
#
# What it does:
#   1. Copies <stack>/ into <target-dir> (excluding .git).
#   2. Initializes a fresh git repo on `main` in the target.
#   3. Prints next steps (follow the target's SETUP.md from Step 2).

set -euo pipefail

STACK="${1:-}"
TARGET="${2:-}"
VALID=("react-native" "flutter")

# ── Validate args ────────────────────────────────────────────────────────────

if [[ -z "$STACK" ]] || [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <stack> <target-dir>"
  echo "  Stacks: ${VALID[*]}"
  exit 1
fi

if ! printf '%s\n' "${VALID[@]}" | grep -qx "$STACK"; then
  echo "Error: unknown stack '$STACK'."
  echo "  Available: ${VALID[*]}"
  exit 1
fi

# ── Resolve paths ────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SRC="$REPO_ROOT/$STACK"

if [[ ! -d "$SRC" ]]; then
  echo "Error: stack source not found at $SRC"
  echo "Did you clone the template repo fully? Run: git clone https://gitea.com/daki.tle.26/ai-project-template.git"
  exit 1
fi

# Expand ~ in target if present
TARGET="${TARGET/#\~/$HOME}"

if [[ -e "$TARGET" ]] && [[ -n "$(ls -A "$TARGET" 2>/dev/null)" ]]; then
  echo "Error: target dir '$TARGET' exists and is not empty."
  echo "  Pick a fresh path, or delete the existing dir first."
  exit 1
fi

# ── Copy + init ──────────────────────────────────────────────────────────────

mkdir -p "$TARGET"

# Copy everything from the stack subdir, excluding any nested .git (shouldn't
# exist, but be defensive).
( cd "$SRC" && tar --exclude=".git" -cf - . ) | ( cd "$TARGET" && tar -xf - )

cd "$TARGET"
git init -b main >/dev/null

echo ""
echo "✓ New $STACK project initialized at: $TARGET"
echo ""
echo "Next steps:"
echo "  cd $TARGET"
echo "  cat SETUP.md      # follow from Step 2 (Step 1 — clone — is already done)"
echo ""
echo "After bootstrap completes, make your first commit:"
echo "  git add ."
echo "  git commit -m 'Initial commit from $STACK template'"
