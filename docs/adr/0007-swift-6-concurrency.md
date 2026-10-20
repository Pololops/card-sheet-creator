# 7. Swift 6 strict concurrency

- Status: accepted
- Date: 2026-10-20

## Context

Swift 6 checks data races at compile time. AppKit printing and SwiftUI run on the main thread; image
decoding and PDF rendering are slow and must not freeze the window.

## Decision

- The app target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency.
- `Domain` holds only `Sendable` value types.
- Heavy work (`SheetRenderer.renderPDF`, thumbnails) is marked `@concurrent` and runs off the main actor.
- `FileLibraryStore` is an actor; the library model chains its saves so they reach the disk in order.
- `Printing` is `@MainActor`; `NSPrintInfo`, `PMPrintSettings` and `PDFDocument` never leave it.

## Consequences

- Most app code needs no concurrency annotations at all.
- A new background task must be explicit (`@concurrent`), which keeps hidden threading out.
