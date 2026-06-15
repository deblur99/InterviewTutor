#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: ./scripts/build-and-notarize.sh <version>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="InterviewTutor"
APP_NAME="InterviewTutor"
ARTIFACT="InterviewTutor-${VERSION}-macOS.zip"
DERIVED_DATA="build/DerivedData"
ENTITLEMENTS="InterviewTutor/InterviewTutor.entitlements"

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
  CODE_SIGN_ENTITLEMENTS="$ENTITLEMENTS" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime"

APP_PATH="${DERIVED_DATA}/Build/Products/Release/${APP_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Verify signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

if codesign -d --entitlements - "$APP_PATH" 2>&1 | grep -q "get-task-allow"; then
  echo "Error: com.apple.security.get-task-allow is present. Distribution builds must not include this entitlement." >&2
  exit 1
fi

echo "==> Create ZIP for notarization"
ditto -c -k --keepParent "$APP_PATH" "$ARTIFACT"

echo "==> Notarize"
SUBMISSION_OUTPUT=$(mktemp)
xcrun notarytool submit "$ARTIFACT" \
  --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
  --wait 2>&1 | tee "$SUBMISSION_OUTPUT"

if grep -q "status: Invalid" "$SUBMISSION_OUTPUT"; then
  SUBMISSION_ID=$(grep -m1 "id:" "$SUBMISSION_OUTPUT" | awk '{print $2}')
  echo "Notarization rejected." >&2
  if [[ -n "$SUBMISSION_ID" ]]; then
    xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" >&2 || true
  fi
  exit 1
fi

if ! grep -q "status: Accepted" "$SUBMISSION_OUTPUT"; then
  echo "Notarization did not reach Accepted status." >&2
  cat "$SUBMISSION_OUTPUT" >&2
  exit 1
fi

echo "==> Staple"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl -a -vv "$APP_PATH"

echo "==> Re-create ZIP after staple"
ditto -c -k --keepParent "$APP_PATH" "$ARTIFACT"

echo "Ready: $ROOT/$ARTIFACT"
