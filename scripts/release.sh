#!/usr/bin/env bash
# Builds a universal, ad-hoc signed app, zips it and publishes it as a GitHub Release.
# Usage: scripts/release.sh 1.0.0
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:?Usage: scripts/release.sh <version>}"
archive=".build/release/CardSheetCreator.xcarchive"
zip="dist/CardSheetCreator.zip"

xcodegen generate --quiet
rm -rf .build/release dist
mkdir -p dist

xcodebuild archive -scheme CardSheetCreator -configuration Release -destination 'generic/platform=macOS' \
  -archivePath "$archive" -derivedDataPath .build/release/dd -quiet \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO MARKETING_VERSION="$version" CODE_SIGN_IDENTITY="-"

app="$archive/Products/Applications/CardSheetCreator.app"
codesign --verify --deep "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"

gh release create "v$version" "$zip" --title "Card Sheet Creator $version" --generate-notes
echo "Published v$version."
