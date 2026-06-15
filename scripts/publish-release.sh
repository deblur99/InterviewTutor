#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: ./scripts/publish-release.sh <version>}"
SKIP_TESTS="${SKIP_TESTS:-0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ARTIFACT="InterviewTutor-${VERSION}-macOS.zip"
WORKFLOW_FILE="release.yml"

if [[ "$SKIP_TESTS" != "1" ]]; then
  ./scripts/test.sh
fi

if ! command -v gh >/dev/null; then
  echo "GitHub CLI (gh) is required. Install: brew install gh" >&2
  exit 1
fi

echo "==> Start GitHub Actions publish workflow"
gh workflow run "$WORKFLOW_FILE" -f "version=${VERSION}"

echo "==> Wait for workflow run"
sleep 5
RUN_ID=""
for _ in $(seq 1 30); do
  RUN_ID=$(gh run list --workflow="$WORKFLOW_FILE" --limit 5 \
    --json databaseId,status,event \
    -q '.[] | select(.status=="in_progress" or .status=="queued") | .databaseId' | head -n1)
  if [[ -n "$RUN_ID" ]]; then
    break
  fi
  sleep 2
done

if [[ -z "$RUN_ID" ]]; then
  echo "Could not find in-progress release workflow run." >&2
  exit 1
fi

echo "Workflow run: $RUN_ID"
echo "==> Build, sign, and notarize locally"
./scripts/build-and-notarize.sh "$VERSION"

echo "==> Upload artifact to workflow run"
gh run upload "$RUN_ID" "$ARTIFACT" --name "$ARTIFACT"

echo "==> Wait for GitHub Release"
gh run watch "$RUN_ID" --exit-status

echo "Published: v${VERSION}"
