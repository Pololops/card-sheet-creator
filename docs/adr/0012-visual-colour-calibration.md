# 12. Visual colour calibration instead of ICC profiles

- Status: accepted — step constants to tune and freeze on the Canon G5000 series
- Date: 2026-10-22

## Context

The goal is prints that look like the screen. The roadmap answer was ICC colour management, but it
cannot work for the printer in use: the Canon G5000 is an AirPrint queue. Its PPD
(`/etc/cups/ppd/AirPrint.ppd`) declares only sRGB through `*cupsICCProfile`, no vendor driver is installed,
and no printer profile exists. Measuring one needs a spectrophotometer or a camera probe, and the user
refuses to depend on one.

What every printer does offer is paper. If the app prints a chart and the user says which patches look
like the screen, the app learns the printer's tendencies without knowing anything about it.

## Decision

- **Probe-free, printer-agnostic visual calibration.** The app prints an A4 chart; the user picks, on
  paper, the patch that matches the screen in four "find the twin" rounds: brightness, contrast, dominant
  (a 3 × 3 grid of warm/cool and green/magenta casts) and colour intensity. Black-and-white queues, told
  apart by `*ColorDevice: False` in their PPD, get brightness and contrast only. A missing PPD counts as
  colour.
- **A correction is five signed integers** (`ColorCorrection`: brightness, contrast, saturation, warmth,
  tint), limited to ±6 for levels and ±2 for casts. One correction is kept per printer, with the driver
  options, driver fingerprint and quality it was measured on.
- **Patches bracket the current setting without inversion.** Each round prints seven (or nine) variants
  around a centre, itself pulled in by the reach (3, or 1 for the grid) so no two patches clamp to the same
  correction. The result is the centre plus the offsets of the picks: the user chose what already looks
  right, so nothing is inverted.
- **Black and white never move.** `CorrectionCurve` applies, in order, a per-channel power for the cast,
  a power for brightness, a sine-based S-curve for contrast and a luma-relative gain for saturation. Each
  stage fixes (0, 0, 0) and (1, 1, 1), so a correction never inks the paper's white, cast included. The
  step sizes are constants tuned once on the G5000 and frozen at release; tests pin direction and
  monotonicity, never values.
- **Core Image carries the curve.** `ColorCorrector` bakes the curve into a 33³ lookup table and applies it
  with `CIColorCubeWithColorSpace` in the image's own colour space (sRGB when it isn't RGB), in a local
  `CIContext` with a float working format so white stays 255.
- **Only the PDF sent to the printer for sheets carries the correction.** `SheetRenderer.renderPDF` takes
  a `ColorCorrection` that defaults to neutral, the exact code path used until now. "Enregistrer en PDF",
  previews, the size calibration page, slot sizes and the layout never receive one.
- **Outdated rule.** A calibration is outdated when the stored driver options differ, the quality differs,
  or both fingerprints are known and differ. The correction is kept and the print dialog warns; an
  unreachable printer is never outdated. Entries live in `settings.json` under `colorCalibrations`, read
  with `decodeIfPresent` like `driverSettings`: no schema bump, no migration.
- **A dedicated window**, "Réglage des couleurs", in five steps (Préparer, Imprimer, Comparer, Vérifier,
  C'est réglé), driven by a flow model that never touches the print dialog's printer. Préparer is a
  checklist for the screen (Night Shift, True Tone and automatic brightness off, a white rectangle that
  matches a sheet of paper), using public APIs only: a link to the Displays settings, no automatic
  toggling. The layout, copy and states follow the approved interactive mockup:
  https://claude.ai/artifact/WKR4H1Q2BFqG6wuqqyDaxw
- **Deviation from [ADR 0010](0010-ui-direction.md)**, which sets one window: this is a second `Window`
  scene. A calibration is a task with its own steps that the user leaves the library to do, with the chart
  in one hand and the screen in the other, and a sheet inside the main window would crowd it.

## Consequences

- The printed PDF is no longer the saved PDF when a correction applies. The exact size is unchanged and
  checked with a ruler.
- Under a correction, PDF artwork is rasterised at 600 dpi instead of staying vector, because a lookup
  table cannot act on vectors; about 10 MB per card while drawing. Without a correction it stays vector.
- Changing a step constant changes what every saved calibration means, so it needs a new ADR.
- ADR [0005](0005-single-core-graphics-pdf-renderer.md) is partially superseded: its "same PDF is printed
  and saved" no longer holds under a correction. Its colour-space and `coverRect` rules stand.
- An older version of the app that re-saves `settings.json` drops `colorCalibrations`: the user
  recalibrates.
- Importing an ICC profile, for printers that ship one, moves to the roadmap's Later list as an
  alternative to this calibration.
- The AirPrint driver may auto-enhance images on its own; the window tells the user to switch that off in
  the printer's options, which only helps if they do.
