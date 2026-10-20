# 3. Feature folders and one local package

- Status: accepted
- Date: 2026-10-20

## Context

The goal is testable units and new features without friction. A full Clean Architecture (use cases,
repositories, presenters, one protocol per class) would mostly add glue code to a small single-user app.

## Decision

- `Packages/CardSheetCore`, one Swift package with four targets whose dependencies enforce the layering:
  - `Domain` — pure value types and rules (grid, distribution, crop, resize). No Apple UI framework.
  - `Rendering` → Domain — sheet to PDF with Core Graphics, thumbnails.
  - `Storage` → Domain — JSON files and the image folder.
  - `Printing` → Domain — the AppKit print adapter.
- `App/CardSheetCreator` — SwiftUI, sliced by feature: `Features/{Library,Templates,Sheets,Printing}`,
  `Shared/` for the library model and reusable controls, `App/` as the composition root.
- Protocols only at system boundaries: `LibraryPersistence` (disk) and `PrintService` (printer).
- Tests follow the classical school: real collaborators, temporary folders for disk I/O, no mocks.

## Consequences

- `swift test` in the package runs the core tests in seconds, without the app.
- A new feature adds a folder under `Features/` and, if it has rules, types in `Domain`.
- Anything reaching the disk or the printer must go through its protocol, which keeps the app testable.
