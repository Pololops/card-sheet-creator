import Domain
import SwiftUI

/// The tiles the user taps once they found their paper's twin: letters only, the paper does the showing.
struct LetterGrid: View {
  let round: CalibrationRound
  let onPick: (ChartVariant) -> Void

  var body: some View {
    LazyVGrid(
      columns: Array(
        repeating: GridItem(.fixed(Design.Metrics.letterTile), spacing: 8), count: round.columnCount),
      alignment: .leading, spacing: 8
    ) {
      ForEach(round.variants, id: \.letter) { variant in
        Button {
          onPick(variant)
        } label: {
          Text(String(variant.letter))
        }
        .buttonStyle(LetterTileStyle())
        .accessibilityLabel("Pastille \(String(variant.letter))")
        .accessibilityHint(variant == round.neutralVariant ? "Réglage actuel" : "")
      }
    }
    .fixedSize()
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Pastilles de ta feuille")
  }
}

private struct LetterTileStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Design.Typography.tileLetter)
      .frame(width: Design.Metrics.letterTile, height: Design.Metrics.letterTile)
      .background(
        configuration.isPressed ? Design.Palette.currentStep : Color.secondary.opacity(0.1),
        in: RoundedRectangle(cornerRadius: 12)
      )
      .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
      .overlay {
        if configuration.isPressed {
          RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: 2)
        }
      }
      .contentShape(RoundedRectangle(cornerRadius: 12))
  }
}
