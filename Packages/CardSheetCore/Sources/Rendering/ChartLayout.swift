import CoreGraphics
import Domain

/// One printed patch: which round and variant it is, and where it sits on the page (mm, y downward).
struct PlacedPatch: Equatable {
  let round: CalibrationRound
  let variant: ChartVariant
  let rect: CGRect
}

/// Where everything goes on the chart and verification pages. All of it stays inside the 5 mm safety box.
enum ChartLayout {
  static let patchSide = 24.0
  static let referenceSide = 48.0
  static let sectionsTop = 35.0

  private static let linearHeight = 38.0
  private static let dominantHeight = 106.0
  private static let patchInset = 8.0
  private static let linearLeft = 12.0
  private static let dominantLeft = 66.0
  private static let patchPitch = 27.0
  private static let dominantRowPitch = 32.0
  private static let letterDrop = 4.5
  private static let referenceLefts = [45.0, 117.0]
  private static let referenceTops = [45.0, 113.0]
  private static let captionDrop = 6.0

  /// Where each round's section starts, in the order given.
  static func sectionTops(for rounds: [CalibrationRound]) -> [(round: CalibrationRound, top: Double)] {
    var top = sectionsTop
    return rounds.map { round in
      defer { top += round == .dominant ? dominantHeight : linearHeight }
      return (round, top)
    }
  }

  static func patches(for rounds: [CalibrationRound]) -> [PlacedPatch] {
    sectionTops(for: rounds).flatMap { section in
      section.round.variants.enumerated().map { index, variant in
        PlacedPatch(round: section.round, variant: variant, rect: rect(of: index, in: section))
      }
    }
  }

  /// One reference patch per round, two to a row, to check the result against the screen.
  static func verificationRects(for rounds: [CalibrationRound]) -> [(round: CalibrationRound, rect: CGRect)] {
    rounds.enumerated().map { index, round in
      let origin = CGPoint(x: referenceLefts[index % 2], y: referenceTops[index / 2])
      return (round, CGRect(origin: origin, size: CGSize(width: referenceSide, height: referenceSide)))
    }
  }

  static func sectionTitlePoint(top: Double) -> CGPoint {
    CGPoint(x: linearLeft, y: top + patchInset / 2)
  }

  static func letterPoint(below rect: CGRect) -> CGPoint {
    CGPoint(x: rect.midX, y: rect.maxY + letterDrop)
  }

  static func captionPoint(below rect: CGRect) -> CGPoint {
    CGPoint(x: rect.midX, y: rect.maxY + captionDrop)
  }

  private static func rect(of index: Int, in section: (round: CalibrationRound, top: Double)) -> CGRect {
    let columns = section.round.columnCount
    let isGrid = section.round == .dominant
    let left = isGrid ? dominantLeft : linearLeft
    let rowPitch = isGrid ? dominantRowPitch : 0
    return CGRect(
      x: left + Double(index % columns) * patchPitch,
      y: section.top + patchInset + Double(index / columns) * rowPitch, width: patchSide, height: patchSide)
  }
}
