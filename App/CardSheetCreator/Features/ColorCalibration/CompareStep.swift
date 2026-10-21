import Domain
import SwiftUI

extension CalibrationRound {
  fileprivate var hint: String {
    switch self {
    case .brightness: "Compare la clarté des gris, du plus foncé au plus clair."
    case .contrast: "Compare l'écart entre les gris foncés et les gris clairs."
    case .dominant:
      "Cherche le gris qui ne tire ni vers le jaune, ni vers le bleu, ni vers le vert ou le rose."
    case .saturation: "Compare la vivacité des couleurs."
    }
  }
}

/// Step 3: one round at a time, "find the twin" of the reference among the lettered patches on paper.
struct CompareStep: View {
  let model: ColorCalibrationModel

  var body: some View {
    VStack(spacing: 0) {
      if let session = model.session, let round = session.currentRound {
        HStack(spacing: 40) {
          reference(of: round)
          question(for: round, session: session)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .frame(maxHeight: .infinity)
        .onChange(of: round) { _, next in
          let position = "Réglage \(session.picks.count + 1) sur \(session.rounds.count)"
          AccessibilityNotification.Announcement("\(position) : \(next.title)").post()
        }
      } else {
        Spacer()
      }
      footer
    }
  }

  private func reference(of round: CalibrationRound) -> some View {
    VStack(spacing: 10) {
      ReferencePatch(
        model: model, round: round, side: Design.Metrics.referenceSide,
        framePadding: Design.Metrics.referenceFramePadding, frameRadius: 18)
      Text("La référence, à l'écran")
        .font(Design.Typography.callout)
        .foregroundStyle(.secondary)
    }
  }

  private func question(for round: CalibrationRound, session: CalibrationSession) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      progress(of: session)
      Text(round.title).font(Design.Typography.stepTitle)
      Text("Trouve sur ta feuille la jumelle de cette pastille.").font(Design.Typography.lead)
      Text(round.hint)
        .font(Design.Typography.body)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      LetterGrid(round: round, onPick: model.pick)
        .padding(.top, 10)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func progress(of session: CalibrationSession) -> some View {
    HStack(spacing: 10) {
      Text("Réglage \(session.picks.count + 1) sur \(session.rounds.count)")
        .font(Design.Typography.callout.weight(.semibold))
        .foregroundStyle(.secondary)
      HStack(spacing: 5) {
        ForEach(session.rounds.indices, id: \.self) { index in
          Circle()
            .fill(index <= session.picks.count ? Color.accentColor : Color.secondary.opacity(0.18))
            .frame(width: 8, height: 8)
        }
      }
      .accessibilityHidden(true)
    }
  }

  private var footer: some View {
    StepFooter {
      if model.canUndoPick {
        Button("Retour", action: model.undoLastPick).secondaryAction()
      }
      Button("Je n'arrive pas à choisir") {
        if let round = model.session?.currentRound { model.pick(round.neutralVariant) }
      }
      .secondaryAction()
    } primary: {
    }
  }
}
