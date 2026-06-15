#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="InterviewTutor"
XCODE_APP_PATH="${XCODE_APP_PATH:-/Applications/Xcode.app}"

if [[ -d "${XCODE_APP_PATH}/Contents/Developer" ]]; then
  sudo xcode-select -s "${XCODE_APP_PATH}/Contents/Developer"
fi

MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if [[ "$MACOS_MAJOR" -lt 26 ]]; then
  echo "Requires macOS 26+. Found: $(sw_vers -productVersion)" >&2
  exit 1
fi

echo "==> Unit tests"
xcodebuild test \
  -project InterviewTutor.xcodeproj \
  -scheme "$SCHEME" \
  -destination 'platform=macOS' \
  -only-testing:InterviewTutorTests

echo "==> UI tests"
xcodebuild test \
  -project InterviewTutor.xcodeproj \
  -scheme "$SCHEME" \
  -destination 'platform=macOS' \
  -only-testing:InterviewTutorUITests

echo "All tests passed."
