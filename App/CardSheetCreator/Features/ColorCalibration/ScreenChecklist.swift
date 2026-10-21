import SwiftUI

extension ColorCalibrationModel.ScreenCheck {
  fileprivate var symbol: String {
    switch self {
    case .nightShift: "moon"
    case .trueTone: "sun.max"
    case .autoBrightness: "sun.max.circle"
    case .whiteMatchesPaper: "doc"
    }
  }

  fileprivate var title: String {
    switch self {
    case .nightShift: "Night Shift désactivé"
    case .trueTone: "True Tone désactivé"
    case .autoBrightness: "Luminosité automatique désactivée"
    case .whiteMatchesPaper: "Le rectangle blanc ressemble à ta feuille"
    }
  }

  fileprivate var explanation: String {
    switch self {
    case .nightShift: "Il jaunit l'écran."
    case .trueTone: "Il change le blanc selon la lumière de la pièce."
    case .autoBrightness: "Sinon elle bouge pendant que tu compares."
    case .whiteMatchesPaper:
      "Tiens une feuille à côté et baisse la luminosité jusqu'à ce qu'ils se ressemblent."
    }
  }
}

/// What the user confirms about the screen before printing: a chart judged on a tinted screen is worthless.
struct ScreenChecklist: View {
  let model: ColorCalibrationModel

  var body: some View {
    let checks = Array(ColorCalibrationModel.ScreenCheck.allCases)
    VStack(spacing: 0) {
      ForEach(checks, id: \.self) { check in
        if check != checks.first { Divider() }
        row(for: check)
      }
    }
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
  }

  private func row(for check: ColorCalibrationModel.ScreenCheck) -> some View {
    Toggle(
      isOn: Binding(
        get: { model.screenChecks.contains(check) }, set: { model.setScreenCheck(check, isOn: $0) })
    ) {
      HStack(spacing: 12) {
        Image(systemName: check.symbol)
          .foregroundStyle(.secondary)
          .frame(width: 18)
        VStack(alignment: .leading, spacing: 1) {
          Text(check.title).font(Design.Typography.body.weight(.medium))
          Text(check.explanation)
            .font(Design.Typography.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .toggleStyle(.checkbox)
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
