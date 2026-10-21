import AppKit
import Domain
import SwiftUI
import UniformTypeIdentifiers

/// ⌘P: printer, its driver options, quality and a locked 100 % A4 layout so cards come out at their exact size.
struct PrintDialog: View {
  @Bindable var controller: PrintController
  let images: ImageCache
  let onSettingsChange: (PrintSettings) -> Void
  @Environment(\.dismiss) private var dismiss

  private static let printersSettingsURL = URL(
    string: "x-apple.systempreferences:com.apple.Print-Scanner-Settings.extension")

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 4) {
        Text(controller.title).font(Design.Typography.dialogTitle)
        Text(controller.sheets.map(\.name).joined(separator: " · "))
          .font(Design.Typography.body).foregroundStyle(.secondary).lineLimit(2)
      }
      previews
      form
      Label(
        "Les cartes sortent à leur taille exacte, \(controller.cardSize), quelle que soit l'imprimante. La marge de 5 mm protège les bords.",
        systemImage: "ruler"
      )
      .font(Design.Typography.callout)
      .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
      if let failure = controller.failure {
        Label(failure, systemImage: "exclamationmark.triangle")
          .font(Design.Typography.callout)
          .foregroundStyle(Design.Palette.warning)
      }
      footer
    }
    .padding(24)
    .frame(width: 540)
    .disabled(controller.isWorking)
    // `initial` persists a stale driver entry the controller dropped while opening.
    .onChange(of: controller.settings, initial: true) { _, settings in onSettingsChange(settings) }
  }

  private var previews: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 18) {
        ForEach(controller.sheets) { sheet in
          VStack(spacing: 6) {
            SheetThumbnail(sheet: sheet, images: images, size: CGSize(width: 84, height: 119))
            Text(sheet.name).font(Design.Typography.caption).foregroundStyle(.secondary).lineLimit(1)
              .frame(maxWidth: 110)
          }
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity)
    }
    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
    .accessibilityHidden(true)
  }

  private var form: some View {
    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 14) {
      GridRow {
        Text("Imprimante").gridColumnAlignment(.trailing)
        printerRow
      }
      GridRow {
        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
        DriverSettingsRow(controller: controller)
      }
      GridRow {
        Text("Qualité")
        qualityControl
      }
      GridRow {
        Text("Mise en page")
        Label("A4 · échelle 100 % · sans ajustement", systemImage: "lock")
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
    }
    .font(Design.Typography.body)
  }

  @ViewBuilder
  private var qualityControl: some View {
    if controller.isDriverControlled {
      Text("Réglée par le pilote").foregroundStyle(.secondary)
    } else {
      VStack(alignment: .leading, spacing: 5) {
        Picker("Qualité", selection: $controller.settings.quality) {
          Text("Brouillon").tag(PrintQuality.draft)
          Text("Optimale").tag(PrintQuality.best)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        Text("Appliquée si l'imprimante la prend en charge.")
          .font(Design.Typography.caption).foregroundStyle(.secondary)
      }
    }
  }

  private var printerSelection: Binding<String?> {
    Binding(get: { controller.settings.printerName }, set: controller.selectPrinter)
  }

  @ViewBuilder
  private var printerRow: some View {
    if controller.printers.isEmpty {
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
        Picker("Imprimante", selection: printerSelection) {
          ForEach(controller.printers, id: \.self) { Text($0).tag(Optional($0)) }
        }
        .labelsHidden()
        if let isReady = controller.isPrinterReady {
          Label(isReady ? "Prête" : "Arrêtée", systemImage: "circle.fill")
            .labelStyle(
              StatusLabelStyle(color: isReady ? Design.Palette.printerReady : Design.Palette.warning)
            )
            .font(Design.Typography.caption)
        }
      }
    }
  }

  private var footer: some View {
    HStack(spacing: 10) {
      Button("Enregistrer en PDF…", action: savePDF)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
      Spacer()
      Button("Annuler") { dismiss() }
        .keyboardShortcut(.cancelAction)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
      Button("Imprimer") {
        Task { if await controller.print() { dismiss() } }
      }
      .keyboardShortcut(.defaultAction)
      .buttonStyle(.glassProminent)
      .disabled(controller.printers.isEmpty)
    }
    .controlSize(.large)
  }

  private func savePDF() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.pdf]
    panel.nameFieldStringValue = "\(controller.sheets.first?.name ?? "Planches").pdf"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    Task { if await controller.exportPDF(to: url) { dismiss() } }
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
