# 11. Driver settings through the native print panel

- Status: accepted — to confirm on the Canon G5000 series
- Date: 2026-10-21

## Context

[ADR 0006](0006-exact-size-printing.md) kept the system print panel out of the app so "scale to fit"
could never be switched on. The cost: the dialog only offers printer and quality, while drivers expose
much more (media type, ink saving, colour mode…). The goal is a Lightroom-style "Options de
l'imprimante…" that reaches every driver pane, while cards keep printing at their exact size.

## Decision

- A standalone, modal `NSPrintPanel.runModal(with:)`, default button "Appliquer", copies visible, page
  range, paper size, orientation and scaling hidden. Printing itself stays panel-less
  (`showsPrintPanel = false`).
- On Apply, the driver settings are stored per printer in `settings.json` and survive relaunches. The
  domain only sees an opaque `DriverSettings { data, fingerprint }`: `NSPrintInfo` and `PMPrintSettings`
  stay inside `Printing`.
- **Sanitize at Apply, warn once.** Overrides that exact-size printing refuses (scale to fit, several
  pages per sheet) are detected on the raw panel output, reported in the dialog until the next
  Apply, Reset or printer change, reset in the data, and never persisted. The page range is forced to
  all pages.
- **Copies are session-only.** They apply to the dialog's prints and calibration always prints one
  copy; the stored data always holds a single copy.
- **Exact size has the last word.** `ExactSizeGuard.enforce` runs last in `makePrintInfo`, for every print
  (sheets and calibration), whatever was restored beneath it. The order is the invariant: printer, then
  restored driver settings (or the app's quality), then plain non-borderless A4, margins 0, scale 1, clip
  pagination, portrait, no centring, layout reset, all pages, copies. Restoring or applying quality after
  it could bring scaling or another paper back.
- **Driver fingerprint.** A stored entry is only trusted while the queue's make and model plus the PPD
  `*FileVersion` match the ones it was made for; otherwise the printer's advanced settings are dropped,
  the basic ones kept, and the dialog says "Réglages avancés réinitialisés : le pilote a changé". An
  unreachable printer (no fingerprint) keeps its stored settings, inactive. The fingerprint is read when
  the dialog opens, on printer change, on Apply, and once when printing.
- While advanced settings are active, the quality picker reads "Réglée par le pilote" and the app's IPP
  and CUPS quality keys are not applied.
- Everything goes through the PrintCore `PM*` functions. The `NSPrintInfo.printSettings` dictionary is
  never written: it mangles dotted keys.

## Consequences

- AirPrint queues have no PPD: their fingerprint is the make and model alone, so a firmware or driver
  update that keeps the model name goes unnoticed. Settings then reach the printer unchanged, but the
  exact-size guard still applies.
- Entries of printers that no longer exist stay in `settings.json`; they are inert and tiny.
- Choosing another printer in the panel moves the dialog's picker to it; switching printer in the
  picker never touches another printer's entry.
- "Save as PDF" and the 0006 calibration checklist are unchanged; this ADR supersedes 0006 only on the
  ban of the system panel.
