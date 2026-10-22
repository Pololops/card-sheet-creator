import AppKit
import SwiftUI

/// Step 1: make the screen trustworthy, then choose the printer the chart goes to.
struct PrepareStep: View {
  let model: ColorCalibrationModel

  private static let displaysSettingsURL = URL(
    string: "x-apple.systempreferences:com.apple.Displays-Settings.extension")

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 28) {
        screenColumn
        printerColumn.frame(width: Design.Metrics.calibrationSideColumn)
      }
      .padding(.horizontal, 32)
      .padding(.vertical, 24)
      .frame(maxHeight: .infinity, alignment: .top)
      StepFooter {
      } primary: {
        Button("Continuer", action: model.continueToPrint)
          .primaryAction()
          .disabled(!model.canContinueToPrint)
      }
    }
  }

  private var screenColumn: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 16) {
        Image(systemName: "swatchpalette")
          .font(.system(size: 40))
          .foregroundStyle(.tint)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 4) {
          Text("Tes cartes, aux bonnes couleurs").font(Design.Typography.stepTitle)
          Text("1 feuille · 5 minutes · aucun matériel")
            .font(Design.Typography.body)
            .foregroundStyle(.secondary)
        }
      }
      Text("Prépare ton écran")
        .font(Design.Typography.body.weight(.semibold))
        .padding(.top, 4)
      ScreenChecklist(model: model)
      HStack(spacing: 14) {
        Button("Ouvrir les réglages Moniteurs", action: openDisplaysSettings).secondaryAction()
        Label("Installe-toi près d'une fenêtre, à la lumière du jour.", systemImage: "window.vertical.open")
          .font(Design.Typography.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var printerColumn: some View {
    VStack(alignment: .leading, spacing: 12) {
      whiteRectangle
      Text("Imprimante")
        .font(Design.Typography.body.weight(.semibold))
        .padding(.top, 4)
      PrinterPicker(
        printers: model.printers,
        selection: Binding(get: { model.printerName }, set: model.selectPrinter),
        isReady: model.isPrinterReady)
      Button("Options de l'imprimante…", action: model.chooseDriverOptions)
        .secondaryAction()
        .disabled(model.printerName == nil)
      if model.printerName != nil && !model.isColorPrinter {
        Label(
          "Imprimante noir et blanc : seuls la luminosité et le contraste se règlent.",
          systemImage: "info.circle"
        )
        .font(Design.Typography.callout)
        .foregroundStyle(.secondary)
      }
      Label(
        "Désactive les corrections automatiques (amélioration photo…) dans les options de l'imprimante.",
        systemImage: "wand.and.stars"
      )
      .font(Design.Typography.callout)
      .foregroundStyle(.secondary)
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
  }

  /// Always white, whatever the appearance: it stands for the sheet the user holds next to the screen.
  private var whiteRectangle: some View {
    ZStack(alignment: .bottomLeading) {
      Design.Palette.paper
      Text("Ce blanc doit ressembler à ta feuille posée à côté.")
        .font(Design.Typography.callout)
        .foregroundStyle(Design.Palette.onPaper)
        .padding(12)
    }
    .frame(height: 132)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
    .accessibilityElement(children: .combine)
  }

  private func openDisplaysSettings() {
    if let url = Self.displaysSettingsURL { NSWorkspace.shared.open(url) }
  }
}
