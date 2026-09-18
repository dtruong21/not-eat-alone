#!/bin/sh
# Copies the flavor-appropriate GoogleService-Info.plist into the built app
# bundle. Wired in as a Run Script build phase on the Runner target (see
# ios/scripts/setup_flavors.rb) so it runs on every build, after the standard
# "Copy Bundle Resources" phase.
#
# Flavor is inferred from $CONFIGURATION (e.g. "Debug-stage", "Release-prod"):
# a configuration name containing "stage" copies the stage plist, everything
# else (including the unflavored base Debug/Release/Profile configs) copies
# prod.
set -e

SRC_ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

case "${CONFIGURATION}" in
  *stage*)
    FLAVOR="stage"
    ;;
  *)
    FLAVOR="prod"
    ;;
esac

SRC_PLIST="${SRC_ROOT}/config/${FLAVOR}/GoogleService-Info.plist"
DEST_PLIST="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"

if [ ! -f "${SRC_PLIST}" ]; then
  echo "error: ${SRC_PLIST} not found (flavor: ${FLAVOR}, CONFIGURATION: ${CONFIGURATION})"
  exit 1
fi

echo "[copy_firebase_plist] Copying ${FLAVOR} GoogleService-Info.plist (CONFIGURATION=${CONFIGURATION})"
cp -f "${SRC_PLIST}" "${DEST_PLIST}"
