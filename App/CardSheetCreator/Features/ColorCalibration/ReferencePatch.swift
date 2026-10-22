import Domain
import SwiftUI

/// What the paper must look like, drawn on a neutral grey frame: grey surrounds do not sway the eye the
/// way the window background would, and the frame ignores dark mode on purpose.
struct ReferencePatch: View {
  let model: ColorCalibrationModel
  let round: CalibrationRound
  let side: CGFloat
  let framePadding: CGFloat
  let frameRadius: CGFloat

  @State private var image: CGImage?

  var body: some View {
    Group {
      if let image {
        Image(decorative: image, scale: 1).resizable().interpolation(.high)
      } else {
        Color.clear
      }
    }
    .frame(width: side, height: side)
    .clipShape(RoundedRectangle(cornerRadius: 4))
    .padding(framePadding)
    .background(Design.Palette.referenceFrame, in: RoundedRectangle(cornerRadius: frameRadius))
    .task(id: round) { image = model.referenceImage(for: round) }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Référence : \(round.title)")
    .accessibilityAddTraits(.isImage)
  }
}
