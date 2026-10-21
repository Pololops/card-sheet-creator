# 6. Exact-size printing on standard A4

- Status: accepted — to confirm with the calibration page on the Canon G5000 series; superseded in part by [0011](0011-driver-settings-through-native-panel.md)
- Date: 2026-10-20

## Context

Cards must print at their exact size on any printer. The user asked for "A4, 100 %, no margins".

Findings:

- A driver's "A4 borderless" paper enlarges the page by about 1 % to bleed off the edges, which would
  make an 85.6 mm card print around 86.5 mm.
- Printing standard A4 at 100 % never scales: at worst the printer leaves out what falls in its
  unprintable border (often 3–5 mm).
- macOS has no public API for print quality. The IPP `print-quality` option (3 draft, 5 high) and the
  CUPS `cupsPrintQuality` key are honoured by AirPrint and many drivers, ignored by others.

## Decision

- Print the rendered PDF with `PDFDocument.printOperation(for:scalingMode: .pageScaleNone)`, without the
  system print panel, so "scale to fit" can never be switched on.
- Pick the driver's plain A4 paper, never a borderless variant; margins 0, scale 1, no centring.
- Keep a fixed 5 mm safety margin in every template: slots can never enter it.
- Set draft / best quality through `print-quality` and `cupsPrintQuality`, presented as "if the printer
  supports it".
- The Calibration menu prints a page with a card outline, two 100 mm rulers and edge marks 1–5 mm from
  each edge, to check a printer in a minute.

## Consequences

- A card measures 54 × 85.6 mm ± 0.5 mm on paper — to verify on the Canon G5000 series.
- If a printer's unprintable border exceeds 5 mm, its edge marks will show it; the margin would then
  need revisiting in a new ADR.
- Without the system panel, "Save as PDF" is offered by the app's own print sheet.
