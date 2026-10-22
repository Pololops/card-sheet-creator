<div align="center">

# Card Sheet Creator

**Print sheets of cards at their exact size, from any Mac, on any printer.**

Build A4 templates of equal slots, drop your card images in, frame them, print.
A 54 × 85.6 mm card comes out at 54 × 85.6 mm.

[**⬇︎ Download for macOS**](https://github.com/Pololops/card-sheet-creator/releases/latest/download/CardSheetCreator.zip)

macOS 26 or later · Apple silicon and Intel · Free · Source available

</div>

---

## What it does

- **Templates** — A4 pages of identical slots. Set width and height in 0.5 mm steps and the gutter in
  1 mm steps; the app fits as many slots as possible inside a 5 mm safety margin and centres the grid.
- **Sheets in one gesture** — drop images from the Finder on a template. One image fills every slot;
  several images take one slot each, spilling onto as many sheets as needed.
- **Framing** — images always cover their slot, edge to edge. Drag one to choose the visible part:
  it snaps to the centre, and every copy of the same image on the sheet follows.
- **Resize a sheet** — change its slot size; images that no longer fit move to a new sheet, never lost.
  Keep the new size as a template if you like.
- **Exact-size printing** — standard A4, forced 100 % scale, no "fit to page", draft or best quality.
  Or save the sheets as a PDF.
- **Printer options** — open the printer's own options (paper type, ink saving, copies…) from the print
  dialog; cards still print at their exact size, whatever the driver offers.
- **Always saved** — every change is written as you go, and ⌘Z undoes it.

Formats: PNG, JPEG, HEIC, TIFF and PDF (first page).

## Install

1. [Download `CardSheetCreator.zip`](https://github.com/Pololops/card-sheet-creator/releases/latest/download/CardSheetCreator.zip)
   and unzip it.
2. Move **CardSheetCreator.app** to your *Applications* folder.
3. Open it. The app is not notarized by Apple, so macOS blocks the first launch:
   open **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
   This is needed once per new version.

Prefer the Terminal? This removes the quarantine flag instead:

```sh
xattr -dr com.apple.quarantine /Applications/CardSheetCreator.app
```

### Check your printer in one minute

Menu **Imprimante → Imprimer la page de calibration…** prints a card outline, two 100 mm rulers and
edge marks. Measure them with a ruler: they should be exact to ± 0.5 mm.

### Match colours

Menu **Imprimante → Régler les couleurs…** prints a chart of patches. Find on paper the patch that looks
like its reference on screen, round after round, and the app remembers one colour correction per
printer. It applies only to what the printer receives: saved PDFs and previews stay as designed, and
white stays paper-white.

## Develop

Requirements: Xcode 27, Homebrew.

```sh
scripts/bootstrap.sh   # installs XcodeGen and generates CardSheetCreator.xcodeproj
scripts/check.sh       # format lint, core tests, app build and tests
```

```
App/CardSheetCreator/        SwiftUI app, one folder per feature
Packages/CardSheetCore/
  Sources/Domain/            pure rules: grid, distribution, framing, resize
  Sources/Rendering/         sheets → A4 PDF with Core Graphics, thumbnails
  Sources/Storage/           JSON library and image folder
  Sources/Printing/          exact-size AppKit printing
docs/adr/                    architecture decisions
docs/manual-e2e.md           release checklist
```

Every structuring decision is recorded in [`docs/adr`](docs/adr). Start with
[0003 — Feature folders and one local package](docs/adr/0003-feature-folders-and-local-package.md) and
[0006 — Exact-size printing](docs/adr/0006-exact-size-printing.md).

### Release

```sh
scripts/release.sh 1.0.0   # universal build, ad-hoc signed, zipped, published as a GitHub Release
```

## License

All rights reserved. See [LICENSE](LICENSE).
