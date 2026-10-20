import AppKit
import Domain
import Observation

/// How big the A4 page is drawn: fitted to the window, at physical size, or at a chosen percentage.
@Observable
final class CanvasZoom {
  enum Mode: Equatable {
    case fit
    case realSize
    case custom(percent: Int)
  }

  /// 100 % when the screen's physical size is unknown: one typographic point per point.
  static let nominalPointsPerMillimetre = 72 / 25.4
  static let step = 10
  static let percentRange = 25...400

  var mode: Mode = .fit

  /// Screen points per millimetre on the main display, or `nil` if the display misreports its size.
  var realSizeScale: Double? {
    guard let screen = NSScreen.main,
      let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    else { return nil }
    let physical = CGDisplayScreenSize(CGDirectDisplayID(number.uint32Value))
    return DisplayScale.pointsPerMillimetre(physicalWidthMm: physical.width, widthPoints: screen.frame.width)
  }

  private var hundredPercentScale: Double { realSizeScale ?? Self.nominalPointsPerMillimetre }

  /// Points per millimetre for a canvas of `available` size.
  func scale(fitting available: CGSize) -> Double {
    switch mode {
    case .fit:
      let width = available.width / Page.a4.width.mm
      let height =
        (available.height - Design.Metrics.canvasTopInset - Design.Metrics.canvasBottomInset)
        / Page.a4.height.mm
      return max(min(width, height), 0.5)
    case .realSize:
      return hundredPercentScale
    case .custom(let percent):
      return hundredPercentScale * Double(percent) / 100
    }
  }

  func percent(fitting available: CGSize) -> Int {
    Int((scale(fitting: available) / hundredPercentScale * 100).rounded())
  }

  func zoom(by delta: Int, from available: CGSize) {
    let next = percent(fitting: available) + delta
    mode = .custom(percent: min(max(next, Self.percentRange.lowerBound), Self.percentRange.upperBound))
  }
}
