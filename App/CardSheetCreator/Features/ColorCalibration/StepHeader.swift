import SwiftUI

extension ColorCalibrationModel.Step {
  fileprivate static let ordered: [Self] = [.prepare, .print, .compare, .verify, .done]

  fileprivate var title: String {
    switch self {
    case .prepare: "Préparer"
    case .print: "Imprimer"
    case .compare: "Comparer"
    case .verify: "Vérifier"
    case .done: "C'est réglé"
    }
  }
}

/// The five steps in a row: finished ones ticked, the current one highlighted.
struct StepHeader: View {
  let current: ColorCalibrationModel.Step

  var body: some View {
    let steps = ColorCalibrationModel.Step.ordered
    let currentIndex = steps.firstIndex(of: current) ?? 0
    HStack(spacing: 6) {
      ForEach(Array(steps.enumerated()), id: \.element) { index, step in
        StepPill(
          number: index + 1, count: steps.count, title: step.title,
          state: index < currentIndex ? .done : index == currentIndex ? .current : .upcoming)
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Étapes du réglage")
  }
}

private struct StepPill: View {
  enum Progress { case upcoming, current, done }

  let number: Int
  let count: Int
  let title: String
  let state: Progress

  var body: some View {
    HStack(spacing: 7) {
      marker
      Text(title)
    }
    .font(Design.Typography.callout.weight(state == .current ? .semibold : .medium))
    .foregroundStyle(state == .current ? .primary : .secondary)
    .padding(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 12))
    .background(state == .current ? Design.Palette.currentStep : .clear, in: Capsule())
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Étape \(number) sur \(count) : \(title)")
    .accessibilityValue(accessibilityState)
  }

  private var marker: some View {
    ZStack {
      Circle().fill(state == .current ? Color.accentColor : Design.Palette.progressTrack)
      if state == .done {
        Image(systemName: "checkmark").foregroundStyle(Design.Palette.success)
      } else {
        Text("\(number)").foregroundStyle(state == .current ? Design.Palette.onAccent : .secondary)
      }
    }
    .font(Design.Typography.caption.weight(.bold))
    .frame(width: 20, height: 20)
  }

  private var accessibilityState: String {
    switch state {
    case .upcoming: ""
    case .current: "En cours"
    case .done: "Terminée"
    }
  }
}
