import AppKit
import SwiftUI

/// The printer menu with its ready/stopped badge, or a way to add a printer when none is configured.
struct PrinterPicker: View {
  let printers: [String]
  @Binding var selection: String?
  let isReady: Bool?

  private static let printersSettingsURL = URL(
    string: "x-apple.systempreferences:com.apple.Print-Scanner-Settings.extension")

  var body: some View {
    if printers.isEmpty {
      HStack(spacing: 10) {
        Text("Aucune imprimante configurée").foregroundStyle(.secondary)
        Button("Ouvrir Imprimantes et scanners") {
          if let url = Self.printersSettingsURL { NSWorkspace.shared.open(url) }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
      }
    } else {
      HStack(spacing: 10) {
        Picker("Imprimante", selection: $selection) {
          ForEach(printers, id: \.self) { Text($0).tag(Optional($0)) }
        }
        .labelsHidden()
        if let isReady {
          Label(isReady ? "Prête" : "Arrêtée", systemImage: "circle.fill")
            .labelStyle(
              StatusLabelStyle(color: isReady ? Design.Palette.printerReady : Design.Palette.warning)
            )
            .font(Design.Typography.caption)
        }
      }
    }
  }
}

private struct StatusLabelStyle: LabelStyle {
  let color: Color

  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 5) {
      configuration.icon.font(.system(size: 7)).foregroundStyle(color)
      configuration.title.foregroundStyle(.secondary)
    }
  }
}
