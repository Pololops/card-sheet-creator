# 2. Native Swift and SwiftUI

- Status: accepted
- Date: 2026-10-20

## Context

The app runs on macOS only for now; iOS/iPadOS may follow. Its hard parts are exact-size printing,
image decoding (HEIC, EXIF orientation) and, in V2, ICC colour management — all operating-system features.

Options considered: Swift + SwiftUI; a Rust core with a Swift UI (UniFFI); Tauri (Rust + web UI); Flutter.

## Decision

Swift 6 and SwiftUI, targeting macOS 26.

## Consequences

- Printing, ColorSync and ImageIO are used directly, with full control.
- iOS/iPadOS later means a new app target plus an iOS print adapter; `Domain`, `Rendering` and `Storage`
  carry over unchanged because they never import AppKit.
- Windows and Android are out of reach. If they become a real target, revisit with Flutter or Tauri.
