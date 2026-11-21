#!/usr/bin/env bash
# Builds a universal, ad-hoc signed app, zips it, signs the zip and publishes both as a GitHub Release.
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

# Why: see docs/adr/0014-signed-in-app-updates.md (the app only installs archives signed with this key).
# The private key goes from the Keychain to the signer through a pipe, never through a file or an argument.
public=$(security find-generic-password -a "$USER" -s card-sheet-creator-update-signing -w \
  | swift scripts/update-signing.swift sign "$zip")
echo "Signed $zip (public key $public)."

gh release create "v$version" "$zip" "$zip.sig" --title "Card Sheet Creator $version" --generate-notes
echo "Published v$version."
