import SwiftUI

/// Tops the print dialog for a printer that was never calibrated: without a correction, cards risk
/// coming out dark or tinted, so the invitation stays until the printer has one.
struct CalibrationOfferCard: View {
  static let title = "Nouvelle imprimante : règle ses couleurs"

  let onCalibrate: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var hasBounced = false

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: "swatchpalette")
        .font(.system(size: 26))
        .foregroundStyle(Design.Palette.onAccent)
        .symbolEffect(.bounce, options: .nonRepeating, value: hasBounced)
        .frame(width: 44, height: 44)
        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(Self.title).font(Design.Typography.figure)
        Text("Sans réglage, tes cartes risquent de sortir trop sombres ou décalées. 1 feuille · 5 min.")
          .font(Design.Typography.body)
          .fixedSize(horizontal: false, vertical: true)
        Button("Régler les couleurs…", action: onCalibrate)
          .secondaryAction()
          .controlSize(.large)
          .padding(.top, 8)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Design.Palette.offerBackground, in: RoundedRectangle(cornerRadius: 16))
    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Design.Palette.offerStroke))
    .accessibilityElement(children: .contain)
    .accessibilitySortPriority(1)
    .onAppear { hasBounced = !reduceMotion }
  }
}
