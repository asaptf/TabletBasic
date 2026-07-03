#!/bin/bash
# Resolve an xcodebuild -destination string for iOS Simulator.
# Usage:
#   ./scripts/xcode-destination.sh iphone   # first available iPhone
#   ./scripts/xcode-destination.sh ipad     # first available iPad
#   ./scripts/xcode-destination.sh            # iPad if available, else iPhone

set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

pick_device() {
  local family="$1"
  xcrun simctl list devices available |
    awk -v family="$family" -F '[()]' '
      $0 ~ family && $0 !~ /unavailable/ {
        name = $1
        sub(/^[[:space:]]+/, "", name)
        sub(/[[:space:]]+$/, "", name)
        id = $2
        if (id != "" && name != "") {
          print name "|" id
        }
      }
    ' |
    head -1
}

kind="${1:-ipad}"
case "$kind" in
  iphone|iPhone)
    match="$(pick_device "iPhone")"
    ;;
  ipad|iPad)
    match="$(pick_device "iPad")"
    ;;
  *)
    echo "Unknown device family: $kind (use iphone or ipad)" >&2
    exit 1
    ;;
esac

if [ -z "$match" ]; then
  if [ "$kind" = "ipad" ] || [ "$kind" = "iPad" ]; then
    match="$(pick_device "iPhone")"
  else
    match="$(pick_device "iPad")"
  fi
fi

if [ -z "$match" ]; then
  echo "No available iOS Simulator found." >&2
  exit 1
fi

name="${match%%|*}"
id="${match##*|}"
echo "platform=iOS Simulator,id=$id"