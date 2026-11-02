# Changelog

Every notable change to Card Sheet Creator, release by release.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/).

## Roadmap

Planned work, not yet scheduled in a release.

### V2 — colour

- **Saved print and colour profiles** — reuse a printer, paper and colour setup in one click.

### Later

- **Import an ICC profile** — for printers that ship one, as an alternative to visual calibration
  ([ADR 0012](docs/adr/0012-visual-colour-calibration.md)).
- **Developer ID signing and notarization** — no more "Open Anyway" on first launch; needs an Apple
  Developer account ([ADR 0009](docs/adr/0009-ad-hoc-distribution.md)).
- **iOS and iPadOS** — a new app target and an iOS print adapter; Domain, Rendering and Storage carry
  over ([ADR 0002](docs/adr/0002-native-swift-swiftui.md)).
- **Zoom an image inside its slot** — enlarge the picture beyond covering the slot, then frame it.
- **Rotate an image by 90°** — in its slot, for pictures taken sideways.
- **Quick Look** — preview an image or a sheet with the space bar.

## [Unreleased]

### Added

- **Swipe to delete** — swipe two fingers to the left over a template or a sheet in the sidebar to reveal
  a red trash, as in Mail.
- **Pinch to zoom** — pinch on the trackpad to zoom the page between 25 % and 400 %, with a tap of the
  trackpad when you reach a limit.
- **Pinch a slot to resize every slot** — on a template, pinch starting on a slot to resize all the slots at
  once, proportions kept, as a single step ⌘Z undoes. The padlock is left as you set it.
- **Two-finger scroll frames an image** — on a sheet, with a slot selected, scroll with two fingers over it
  to move its image inside the slot, as a single step ⌘Z undoes, with a tap of the trackpad when it
  centres. Anywhere else, the page scrolls as before.
- **Two-finger double-tap** — double-tap with two fingers on the selected image to centre it in its slot;
  anywhere else, it switches the canvas between *Ajuster* and *Taille réelle*.

### Changed

- Holding − or + next to a dimension now repeats the step; one ⌘Z undoes everything done during a press.
- Every deletion now asks for confirmation, from the swipe, the context menu or the Delete key; the dialog
  names what goes away, and *Annuler* is the default
  ([ADR 0013](docs/adr/0013-confirm-every-deletion.md)). ⌘Z still brings it back.

## [0.5.0] — 2026-10-30

### Added

- **Proportion lock** — a padlock between *Largeur* and *Hauteur* keeps a slot's proportions: change one
  side and the other follows, to the tenth of a millimetre. Closed by default; open it to edit each side
  on its own.

## [0.4.0] — 2026-10-22

### Added

- **Colour calibration** — *Imprimante → Régler les couleurs…* opens a five-step assistant: print a colour
  chart, pick on paper the patches that match the screen, and that printer's sheets print closer to what
  you see. White stays paper-white; saved PDFs, previews and exact size are unchanged
  ([ADR 0012](docs/adr/0012-visual-colour-calibration.md)).
- The print dialog invites you to set the colours of a printer that has none, and lets you switch a
  correction off, redo it or reset it; it warns when the printer's options or quality changed since.

### Changed

- The *Calibration* menu is now *Imprimante*.

## [0.3.0] — 2026-10-21

### Added

- Import WebP, GIF, BMP and AVIF images.

### Changed

- The image picker's confirm button reads "Sélectionner" instead of "Ouvrir".

### Fixed

- Picking images for a new sheet now creates the sheet; it silently did nothing before.

## [0.2.1] — 2026-10-21

### Changed

- License is now "all rights reserved". Versions released before this change remain under the MIT
  License.

## [0.2.0] — 2026-10-21

### Added

- **Printer options** in the print dialog open the printer's own settings (paper type, colour, duplex,
  copies…). Settings are kept per printer and dropped when the driver changes; choices that would
  break exact size are ignored and named in a warning
  ([ADR 0011](docs/adr/0011-driver-settings-through-native-panel.md)).

### Changed

- Exact size is enforced last on every print, calibration page included.

## [0.1.5] — 2026-10-21

### Added

- Deselect with Escape, or a click beside the page or on an empty slot.
- Open-hand cursor over images that can be reframed.

### Fixed

- Empty slots no longer show the previous sheet's image.
- Clicks and drags hit the slot under the pointer, and drags commit reliably.
- Inspectors no longer force the window taller.
- Toolbar glass shadow redraws when switching modes.
- Template thumbnail outlines stay visible on a selected row.

### Removed

- Disabled print button and read-only crop slider.

## [0.1.0] — 2026-10-20

First release.

### Added

- **Templates** — A4 pages of identical slots, 0.5 mm slot steps, adjustable gutter, 5 mm safety
  margin, centred grid.
- **Sheets** — drop images on a template: one image fills every slot, several spill onto as many
  sheets as needed.
- **Framing** — images cover their slot; drag to choose the visible part, with centre snapping and
  every copy of the same image following.
- **Resize a sheet** — images that no longer fit move to a new sheet; keep the new size as a template.
- **Exact-size printing** — standard A4 at forced 100 %, draft or best quality, or save as PDF.
- **Calibration page** to check a printer with a ruler.
- **Always saved** — autosaved library, ⌘Z undo.
- Liquid Glass app icon.
- Formats: PNG, JPEG, HEIC, TIFF and PDF (first page).

[Unreleased]: https://github.com/Pololops/card-sheet-creator/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/Pololops/card-sheet-creator/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/Pololops/card-sheet-creator/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/Pololops/card-sheet-creator/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/Pololops/card-sheet-creator/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/Pololops/card-sheet-creator/compare/v0.1.5...v0.2.0
[0.1.5]: https://github.com/Pololops/card-sheet-creator/compare/v0.1.0...v0.1.5
[0.1.0]: https://github.com/Pololops/card-sheet-creator/releases/tag/v0.1.0
