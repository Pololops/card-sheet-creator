import Printing
import SwiftUI

/// Under the printer: the way into the driver's own options, and what they are doing to this print.
struct DriverSettingsRow: View {
  let controller: PrintController

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Button("Options de l'imprimante…", action: controller.editDriverSettings)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .disabled(controller.printers.isEmpty)
      if controller.isDriverControlled { activeLine }
      if controller.wasDriverReset {
        Label("Réglages avancés réinitialisés : le pilote a changé", systemImage: "arrow.counterclockwise")
          .font(Design.Typography.caption)
          .foregroundStyle(.secondary)
      }
      ForEach(ExactSizeOverride.allCases.filter(controller.overrides.contains), id: \.self) { override in
        Label(Self.warning(for: override), systemImage: "exclamationmark.triangle")
          .font(Design.Typography.caption)
          .foregroundStyle(Design.Palette.warning)
      }
    }
  }

  private var activeLine: some View {
    HStack(spacing: 8) {
      Label(activeText, systemImage: "slider.horizontal.3")
        .foregroundStyle(.secondary)
      Button("Réinitialiser", action: controller.resetDriverSettings)
        .buttonStyle(.link)
        .accessibilityLabel("Réinitialiser les réglages avancés")
    }
    .font(Design.Typography.caption)
  }

  private var activeText: String {
    let base = "Réglages avancés de la dernière impression actifs"
    return controller.copies > 1 ? "\(base) · \(controller.copies) copies" : base
  }

  private static func warning(for override: ExactSizeOverride) -> String {
    switch override {
    case .scaleToFit: "Ajustement à la page ignoré : les cartes restent à 100 %"
    case .pagesPerSheet: "Plusieurs pages par feuille ignoré : une planche par feuille"
    }
  }
}
