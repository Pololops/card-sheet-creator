# 9. Ad-hoc signed builds on GitHub Releases

- Status: superseded by [0014](0014-signed-in-app-updates.md)
- Date: 2026-10-20

## Context

The app must install on other Macs (macOS 26) without Xcode. There is no paid Apple Developer account,
so Developer ID signing and notarization are not available.

## Decision

`scripts/release.sh <version>` archives a universal (arm64 + x86_64) Release build, signed ad hoc,
zips it with `ditto` and publishes `CardSheetCreator.zip` as a GitHub Release. The README links to
`releases/latest/download/CardSheetCreator.zip`, which always points at the newest version.

## Consequences

- Gatekeeper blocks the first launch of each version; the README explains "Open Anyway" and the
  `xattr` alternative.
- Moving to Developer ID later only changes the signing step of the script.
