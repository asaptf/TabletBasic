#!/bin/bash
# Run TabletBasic UI tests and propagate xcodebuild's real exit code.
# Do not pipe xcodebuild through grep|head — that causes false exit code 65
# when lines like "xcrun: error: ... simctl" match grep "error:".

set -uo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -z "${DESTINATION:-}" ]; then
  DEVICE_KIND="${DEVICE_KIND:-ipad}"
  DESTINATION="$("$ROOT/scripts/xcode-destination.sh" "$DEVICE_KIND")"
fi
LOG="${LOG:-/tmp/tabletbasic-uitest.log}"

TESTS=("$@")
if [ ${#TESTS[@]} -eq 0 ]; then
  # Default: small smoke subset from SampleProgramsUITests.swift.
  # Full suite (pass as args or run without -only-testing filters):
  #   TabletBasicUITests/SampleProgramsUITests/testLibraryListsAllSamplePrograms
  #   TabletBasicUITests/SampleProgramsUITests/testEverySampleProgramRunsFromEditor
  #   TabletBasicUITests/SampleProgramsUITests/testEverySampleProgramLoadsAndRunsFromLibrary
  #   TabletBasicUITests/SampleProgramsUITests/testEverySampleProgramLoadsAndRuns
  TESTS=(
    "TabletBasicUITests/SampleProgramsUITests/testLibraryListsAllSamplePrograms"
  )
fi

ARGS=()
for test in "${TESTS[@]}"; do
  ARGS+=(-only-testing:"$test")
done

echo "Destination: $DESTINATION"
echo "Running UI tests: ${TESTS[*]}"
echo "Log: $LOG"

set +e
xcodebuild -project TabletBasic.xcodeproj -scheme TabletBasic \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO \
  "${ARGS[@]}" \
  test 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
set -e

echo
if [ "$STATUS" -eq 0 ]; then
  echo "UI tests passed."
else
  echo "UI tests failed (xcodebuild exit $STATUS)."
  grep -E "error: -\[|XCTAssert|Failing tests:" "$LOG" | tail -20 || true
fi

exit "$STATUS"