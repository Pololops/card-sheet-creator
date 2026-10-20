#!/usr/bin/env bash
# Prepares a fresh clone: installs XcodeGen if needed and generates the Xcode project.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null; then
  brew install xcodegen
fi
xcodegen generate
echo "Open CardSheetCreator.xcodeproj, or run scripts/check.sh."
