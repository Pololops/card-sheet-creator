import SwiftUI

/// Step 2: print the chart, then wait for the ink to dry before comparing.
struct PrintStep: View {
  let model: ColorCalibrationModel

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private enum Phase { case idle, printing, failed, drying, dry }

  private var phase: Phase {
    if model.isPrinting { return .printing }
    if model.isInkWet { return .drying }
    if model.dryingEndsAt != nil { return .dry }
    return model.failure == nil ? .idle : .failed
  }

  var body: some View {
    VStack(spacing: 0) {
      content
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
      footer
    }
    .onChange(of: model.failure) { _, failure in
      if let failure { AccessibilityNotification.Announcement(failure).post() }
    }
  }

  @ViewBuilder
  private var content: some View {
    switch phase {
    case .idle: idle
    case .printing: printing
    case .failed: failed
    case .drying, .dry: drying
    }
  }

  private var printerIcon: some View {
    Image(systemName: "printer")
      .font(.system(size: 72))
      .foregroundStyle(.secondary)
      .symbolEffect(.pulse, isActive: phase == .printing && !reduceMotion)
      .accessibilityHidden(true)
  }

  private var idle: some View {
    VStack(spacing: 18) {
      printerIcon
      Text("Imprime la mire couleur").font(Design.Typography.stepTitle)
      Text(
        "Une page A4 de pastilles, imprimée avec les mêmes réglages que tes planches. Mets le papier que tu utilises d'habitude."
      )
      .font(Design.Typography.body)
      .foregroundStyle(.secondary)
      .frame(maxWidth: 440)
      if model.isPrinterReady == false {
        Label(
          "L'imprimante est arrêtée : relance-la avant d'imprimer.", systemImage: "exclamationmark.triangle"
        )
        .font(Design.Typography.callout)
        .foregroundStyle(Design.Palette.warning)
      }
    }
  }

  private var printing: some View {
    VStack(spacing: 18) {
      printerIcon
      HStack(spacing: 10) {
        ProgressView().controlSize(.small)
        Text("Impression de la mire…").font(Design.Typography.body)
      }
    }
  }

  private var failed: some View {
    VStack(spacing: 18) {
      printerIcon
      Text("La mire n'est pas sortie").font(Design.Typography.stepTitle)
      if let failure = model.failure {
        Label(failure, systemImage: "exclamationmark.triangle")
          .font(Design.Typography.body)
          .foregroundStyle(Design.Palette.warning)
          .frame(maxWidth: 460)
      }
    }
  }

  private var drying: some View {
    VStack(spacing: 18) {
      DryingRing(model: model, diameter: Design.Metrics.dryingRing)
      Text(model.isInkWet ? "Laisse sécher l'encre" : "L'encre est sèche")
        .font(Design.Typography.stepTitle)
      Text(
        model.isInkWet
          ? "L'encre change un peu de teinte en séchant : on attend avant de comparer."
          : "Pose la feuille à côté de l'écran, c'est parti."
      )
      .font(Design.Typography.body)
      .foregroundStyle(.secondary)
      .frame(maxWidth: 440)
    }
  }

  private var footer: some View {
    StepFooter {
      if phase == .idle || phase == .failed {
        Button("Retour", action: model.goBackToPrepare).secondaryAction()
      }
    } primary: {
      switch phase {
      case .idle, .printing:
        Button("Imprimer la mire couleur") { Task { await model.printChart() } }
          .primaryAction()
          .disabled(phase == .printing)
      case .failed:
        Button("Réessayer l'impression") { Task { await model.printChart() } }.primaryAction()
      case .drying, .dry:
        Button("Comparer", action: model.startComparing)
          .primaryAction()
          .disabled(!model.canStartComparing)
      }
    }
  }
}
