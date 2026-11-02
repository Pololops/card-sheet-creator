import SwiftUI

/// Pinching zooms the page between the zoom limits. The gesture sits on the scrolling content, so it covers
/// the gutters, the hatched band, the grey canvas and every sheet.
struct CanvasPinch: ViewModifier {
  let zoom: CanvasZoom
  let available: CGSize

  @GestureState private var active: ActivePinch?
  @State private var isAtLimit = false

  struct ActivePinch: Equatable {
    var startPercent: Int
  }

  func body(content: Content) -> some View {
    content
      .gesture(pinch)
      // Only the edge into a limit taps the trackpad: holding at the limit stays silent.
      .sensoryFeedback(.levelChange, trigger: isAtLimit) { wasAtLimit, isNowAtLimit in
        !wasAtLimit && isNowAtLimit
      }
  }

  private var pinch: some Gesture {
    MagnifyGesture()
      .updating($active) { value, active, _ in
        let start = active ?? ActivePinch(startPercent: zoom.percent(fitting: available))
        active = start
        isAtLimit = zoom.magnify(from: start.startPercent, by: value.magnification)
      }
      .onEnded { _ in isAtLimit = false }
  }
}
