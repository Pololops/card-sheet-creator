#!/usr/bin/env bash
# The verification gate: format lint, core tests, then app build and tests.
set -euo pipefail
cd "$(dirname "$0")/.."

swift format lint --strict -r App Packages/CardSheetCore/Sources Packages/CardSheetCore/Tests
swift test --package-path Packages/CardSheetCore
xcodegen generate --quiet
xcodebuild -scheme CardSheetCreator -destination 'platform=macOS' -derivedDataPath .build/dd -quiet test
echo "All checks passed."
