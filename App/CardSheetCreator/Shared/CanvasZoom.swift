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

  static func clampedPercent(_ percent: Int) -> Int {
    min(max(percent, percentRange.lowerBound), percentRange.upperBound)
  }

  func zoom(by delta: Int, from available: CGSize) {
    mode = .custom(percent: Self.clampedPercent(percent(fitting: available) + delta))
  }

  /// Scales from the percentage the pinch started at, so every update of one gesture is independent of the
  /// previous one. Returns true when the zoom is held at a limit.
  @discardableResult
  func magnify(from startPercent: Int, by magnification: Double) -> Bool {
    let requested = Int((Double(startPercent) * magnification).rounded())
    let clamped = Self.clampedPercent(requested)
    mode = .custom(percent: clamped)
    return clamped != requested
  }
}
