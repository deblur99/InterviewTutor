#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: ./scripts/build-and-notarize.sh <version>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="InterviewTutor"
APP_NAME="InterviewTutor"
ARTIFACT="InterviewTutor-${VERSION}-macOS.zip"
DERIVED_DATA="build/DerivedData"

XCODE_APP_PATH="${XCODE_APP_PATH:-/Applications/Xcode.app}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Hyeonmin Han (44HRTG996V)}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-44HRTG996V}"
NOTARY_KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-AC_NOTARY}"

if [[ -d "${XCODE_APP_PATH}/Contents/Developer" ]]; then
  sudo xcode-select -s "${XCODE_APP_PATH}/Contents/Developer"
fi

MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if [[ "$MACOS_MAJOR" -lt 26 ]]; then
  echo "Requires macOS 26+. Found: $(sw_vers -productVersion)" >&2
  exit 1
fi

echo "==> Build Release"
xcodebuild build \
  -project InterviewTutor.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime"

APP_PATH="${DERIVED_DATA}/Build/Products/Release/${APP_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Verify signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "==> Create ZIP for notarization"
ditto -c -k --keepParent "$APP_PATH" "$ARTIFACT"

echo "==> Notarize"
xcrun notarytool submit "$ARTIFACT" \
  --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
  --wait

echo "==> Staple"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl -a -vv "$APP_PATH"

echo "==> Re-create ZIP after staple"
ditto -c -k --keepParent "$APP_PATH" "$ARTIFACT"

echo "Ready: $ROOT/$ARTIFACT"
