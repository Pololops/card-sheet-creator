import CoreGraphics
import Domain

/// The bitmap a round prints in each of its patches, before any correction. Each pattern is built so the
/// quality being judged shows at a glance, whatever the paper does to it.
enum ChartPatch {
  private static let pixelsPerMillimetre = 300.0 / 25.4

  private struct Tile {
    /// In the unit square, y growing downward.
    let rect: CGRect
    let color: CGColor
  }

  /// An sRGB bitmap of the pattern for a square of `side` millimetres at 300 dpi.
  static func image(for round: CalibrationRound, side: Double) throws(RenderError) -> CGImage {
    let pixels = Int((side * pixelsPerMillimetre).rounded())
    let scale = Double(pixels)
    return try Thumbnails.rasterize(width: pixels, height: pixels) { context in
      for tile in tiles(for: round) {
        context.setFillColor(tile.color)
        context.fill(
          CGRect(
            x: tile.rect.minX * scale, y: tile.rect.minY * scale, width: tile.rect.width * scale,
            height: tile.rect.height * scale))
      }
    }
  }

  private static func tiles(for round: CalibrationRound) -> [Tile] {
    switch round {
    case .brightness: brightnessBands
    case .contrast: contrastBlocks
    case .dominant: dominantSquare
    case .saturation: saturationSwatches
    }
  }

  /// Four flat greys: the eye compares each shade with the screen's.
  private static var brightnessBands: [Tile] {
    [0.2, 0.4, 0.6, 0.8].enumerated().map { index, grey in
      Tile(rect: CGRect(x: 0, y: Double(index) / 4, width: 1, height: 0.25), color: gray(grey))
    }
  }

  /// Contrast is judged as how far apart two greys look, so the pairs sit symmetrically around mid-grey.
  private static var contrastBlocks: [Tile] {
    let blocks = [(0.0, 0.0, 0.3), (0.5, 0.0, 0.7), (0.0, 0.5, 0.15), (0.5, 0.5, 0.85)]
    return blocks.map { Tile(rect: CGRect(x: $0, y: $1, width: 0.5, height: 0.5), color: gray($2)) }
  }

  /// A light square on mid-grey: a colour cast shows on neutral tones far better than on saturated ones.
  private static var dominantSquare: [Tile] {
    let third = 1.0 / 3
    return [
      Tile(rect: CGRect(x: 0, y: 0, width: 1, height: 1), color: gray(0.55)),
      Tile(rect: CGRect(x: third, y: third, width: third, height: third), color: gray(0.8)),
    ]
  }

  private static var saturationSwatches: [Tile] {
    let colors = [
      (0.80, 0.25, 0.22), (0.95, 0.80, 0.25), (0.35, 0.65, 0.35),
      (0.40, 0.62, 0.90), (0.58, 0.40, 0.75), (0.92, 0.74, 0.62),
    ]
    return colors.enumerated().map { index, color in
      Tile(
        rect: CGRect(x: Double(index % 3) / 3, y: Double(index / 3) / 2, width: 1.0 / 3, height: 0.5),
        color: CGColor(srgbRed: color.0, green: color.1, blue: color.2, alpha: 1))
    }
  }

  private static func gray(_ value: Double) -> CGColor {
    CGColor(srgbRed: value, green: value, blue: value, alpha: 1)
  }
}
