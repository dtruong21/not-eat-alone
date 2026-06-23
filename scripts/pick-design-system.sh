#!/usr/bin/env bash
# pick-design-system.sh — copies the chosen design system into the project,
# then removes the rest. Run this once during SETUP.md Step 3.5.
#
# Usage:
#   ./scripts/pick-design-system.sh notion-github
#   ./scripts/pick-design-system.sh linear-minimal
#   ./scripts/pick-design-system.sh warm-playful

set -euo pipefail

CHOICE="${1:-}"
VALID=("notion-github" "linear-minimal" "warm-playful")

if [[ -z "$CHOICE" ]] || ! printf '%s\n' "${VALID[@]}" | grep -qx "$CHOICE"; then
  echo "Usage: $0 <system>"
  echo "  Available systems: ${VALID[*]}"
  echo ""
  echo "  Read design-systems/README.md to choose."
  exit 1
fi

SRC="design-systems/$CHOICE"
if [[ ! -d "$SRC" ]]; then
  echo "Error: $SRC not found. Run from project root."
  exit 1
fi

# Create target folders
mkdir -p lib/design
mkdir -p docs

# Copy the chosen system
cp "$SRC/tokens.ts" lib/design/tokens.ts
cp "$SRC/tailwind.preset.js" lib/design/tailwind.preset.js
cp "$SRC/DESIGN.md" docs/DESIGN.md
cp "$SRC/mood.svg" docs/design-mood.svg

echo "✓ Copied $CHOICE → lib/design/tokens.ts + lib/design/tailwind.preset.js"
echo "✓ Copied $CHOICE → docs/DESIGN.md + docs/design-mood.svg"

# Remove the design-systems folder — final project carries only the chosen system.
# Comment out the next line if you want to keep the others around for reference.
rm -rf design-systems
echo "✓ Removed design-systems/ — final project carries only the chosen system"

echo ""
echo "Next steps:"
echo "  1. Wire lib/design/tailwind.preset.js into your tailwind.config.js"
echo "     (see lib/design/tailwind.preset.js header comment)"
echo "  2. Install the chosen system's fonts via expo-font (Inter / Nunito / JetBrains Mono)"
echo "  3. Review docs/DESIGN.md and customize for your brand"
