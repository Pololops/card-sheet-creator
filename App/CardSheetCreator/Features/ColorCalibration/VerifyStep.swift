import Domain
import SwiftUI

/// Step 4, optional: print the chart again with the result applied, and see whether every patch now
/// looks like its reference.
struct VerifyStep: View {
  let model: ColorCalibrationModel

  private enum Phase { case ask, printing, drying, dry }

  private var phase: Phase {
    if model.isPrinting { return .printing }
    if model.isInkWet { return .drying }
    return model.dryingEndsAt == nil ? .ask : .dry
  }

  var body: some View {
    VStack(spacing: 0) {
      content
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
      footer
    }
  }

  @ViewBuilder
  private var content: some View {
    switch phase {
    case .ask: ask
    case .printing: printing
    case .drying: drying
    case .dry: comparison
    }
  }

  private var ask: some View {
    VStack(spacing: 16) {
      Image(systemName: "checkmark.rectangle.portrait")
        .font(.system(size: 72))
        .foregroundStyle(.tint)
        .accessibilityHidden(true)
      Text("Vérifie le résultat").font(Design.Typography.stepTitle)
      Text(
        "Imprime une feuille de vérification, déjà corrigée : chaque pastille doit maintenant ressembler à sa référence à l'écran."
      )
      .font(Design.Typography.body)
      .foregroundStyle(.secondary)
      .frame(maxWidth: 470)
      Text("Étape facultative · une feuille de plus")
        .font(Design.Typography.callout)
        .foregroundStyle(.secondary)
      if let failure = model.failure {
        Label(failure, systemImage: "exclamationmark.triangle")
          .font(Design.Typography.callout)
          .foregroundStyle(Design.Palette.warning)
      }
    }
  }

  private var printing: some View {
    HStack(spacing: 10) {
      ProgressView().controlSize(.small)
      Text("Impression de la vérification…").font(Design.Typography.body)
    }
  }

  private var drying: some View {
    VStack(spacing: 16) {
      DryingRing(model: model, diameter: Design.Metrics.verificationRing)
      Text("Laisse sécher l'encre").font(Design.Typography.stepTitle)
    }
  }

  private var comparison: some View {
    VStack(spacing: 16) {
      Text("Chaque pastille ressemble-t-elle à sa référence ?").font(Design.Typography.stepTitle)
      HStack(spacing: 14) {
        ForEach(model.session?.rounds ?? [], id: \.self) { round in
          VStack(spacing: 8) {
            ReferencePatch(
              model: model, round: round, side: Design.Metrics.verificationReferenceSide,
              framePadding: 12, frameRadius: 14)
            Text(round.title).font(Design.Typography.callout).foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private var footer: some View {
    StepFooter {
      if phase == .ask {
        Button("Passer cette étape", action: model.finish).secondaryAction()
      } else if phase != .printing {
        Button("Affiner", action: model.refine).secondaryAction().disabled(model.isInkWet)
      }
    } primary: {
      switch phase {
      case .ask, .printing:
        Button("Imprimer la vérification") { Task { await model.printVerification() } }
          .primaryAction()
          .disabled(phase == .printing)
      case .drying:
        Button("Vérifier sans attendre", action: model.skipDrying).secondaryAction()
      case .dry:
        Button("Tout correspond", action: model.finish).primaryAction()
      }
    }
  }
}
