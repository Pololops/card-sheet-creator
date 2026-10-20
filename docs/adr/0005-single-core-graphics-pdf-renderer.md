# 5. One Core Graphics PDF renderer, one crop function

- Status: accepted
- Date: 2026-10-20

## Context

What the user frames on screen must be exactly what prints, in millimetres. V2 will add ICC profiles,
rendering intents and manual corrections.

## Decision

- `SheetRenderer` draws sheets into an A4 PDF with `CGContext(consumer:mediaBox:)`: 1 mm = 72 / 25.4 pt,
  each image clipped to its slot. The same PDF is printed and saved; thumbnails use the same drawing code.
- `Crop.coverRect` (Domain) places an image in its slot. It is used both by the on-screen editor and by
  the renderer, so screen and paper cannot drift apart.
- Images keep their source colour space (no flattening to device RGB) — the hook for V2 colour management.
- Bitmaps are decoded with `CGImageSourceCreateThumbnailAtIndex` (EXIF orientation applied, capped near
  600 dpi); PDF sources keep page 1 as vectors.

## Consequences

- Rendering is tested by reading the PDF back: page size, pixel colours, embedded ICC profile.
- No slot outline, guide or cut mark is ever drawn by the renderer; those exist only in SwiftUI views.
