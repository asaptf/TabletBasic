#!/bin/bash
# Build TabletBasic for an available iOS Simulator.
# Usage:
#   ./scripts/build.sh          # iPad simulator (fallback: iPhone)
#   ./scripts/build.sh iphone   # iPhone simulator
#   ./scripts/build.sh ipad     # iPad simulator

set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

KIND="${1:-ipad}"
DESTINATION="$("$ROOT/scripts/xcode-destination.sh" "$KIND")"

echo "Destination: $DESTINATION"
xcodegen generate >/dev/null

xcodebuild -project TabletBasic.xcodeproj -scheme TabletBasic \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO \
  build