import Domain
import SwiftUI

/// The "Couleurs" line of the print dialog: whether the printer has a correction, whether this print
/// uses it, and the ways to redo or forget it.
struct ColorCorrectionRow: View {
  let controller: PrintController
  let onCalibrate: () -> Void

  var body: some View {
    if let calibration = controller.colorCalibration {
      calibrated(calibration)
    } else {
      Text("Non réglées").foregroundStyle(.secondary)
    }
  }

  private func calibrated(_ calibration: PrinterCalibration) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Label(
        "Correction · réglée le \(calibration.calibratedAt.formatted(.dateTime.day().month(.abbreviated)))",
        systemImage: "swatchpalette")
      Toggle(
        "Appliquer la correction",
        isOn: Binding(
          get: { controller.colorCalibration?.isApplied ?? false }, set: controller.setCorrectionApplied)
      )
      .toggleStyle(.checkbox)
      HStack(spacing: 12) {
        Button("Régler à nouveau…", action: onCalibrate).secondaryAction()
        Button("Réinitialiser", action: controller.resetColorCalibration)
          .buttonStyle(.link)
          .font(Design.Typography.callout)
          .accessibilityLabel("Réinitialiser la correction des couleurs")
      }
      notices(for: calibration)
    }
  }

  @ViewBuilder
  private func notices(for calibration: PrinterCalibration) -> some View {
    if controller.isColorCalibrationOutdated {
      Label(
        "Les options de l'imprimante ont changé depuis le réglage des couleurs",
        systemImage: "exclamationmark.triangle"
      )
      .font(Design.Typography.callout)
      .foregroundStyle(Design.Palette.warning)
    }
    if !calibration.isApplied {
      Text("Cette impression part sans correction.")
        .font(Design.Typography.callout)
        .foregroundStyle(.secondary)
    }
  }
}
