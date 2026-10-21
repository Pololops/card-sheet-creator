import CoreGraphics
import Domain
import Testing

@testable import Rendering

@Suite struct ColorCorrectorTests {
  private static let stripeSize = 10
  private let fixtures: ImageFixtures

  init() throws {
    fixtures = try ImageFixtures()
  }

  private func srgb(_ red: Double, _ green: Double, _ blue: Double) -> CGColor {
    CGColor(srgbRed: red, green: green, blue: blue, alpha: 1)
  }

  /// The colour of the `index`th stripe, as bytes.
  private func stripeColor(_ index: Int, in image: CGImage) throws -> Raster.RGB {
    try Raster(image: image, pixelsPerMillimetre: 1).color(
      atMm: Double(index * Self.stripeSize + Self.stripeSize / 2), Double(Self.stripeSize / 2))
  }

  @Test func cubeMatchesTheCurve() throws {
    let samples = [(0.2, 0.4, 0.8), (0.9, 0.5, 0.1), (0.5, 0.5, 0.5), (0.1, 0.1, 0.1)]
    let correction = ColorCorrection(brightness: 3, contrast: 2, saturation: -2, warmth: 1, tint: -1)
    let source = try fixtures.stripes(
      of: samples.map { srgb($0.0, $0.1, $0.2) }, size: Self.stripeSize)

    let corrected = try ColorCorrector(correction: correction).apply(to: source)

    for (index, sample) in samples.enumerated() {
      let expected = CorrectionCurve.apply(SIMD3(sample.0, sample.1, sample.2), correction) * 255
      let actual = try stripeColor(index, in: corrected)
      #expect(abs(Double(actual.red) - expected.x) <= 2)
      #expect(abs(Double(actual.green) - expected.y) <= 2)
      #expect(abs(Double(actual.blue) - expected.z) <= 2)
    }
  }

  @Test(arguments: [
    ColorCorrection(brightness: 6, contrast: 6, saturation: 6, warmth: 2, tint: 2),
    ColorCorrection(brightness: -6, contrast: -6, saturation: -6, warmth: -2, tint: -2),
    ColorCorrection(warmth: 2, tint: -2),
  ])
  func whitePixelsStayPaperWhite(correction: ColorCorrection) throws {
    let source = try fixtures.stripes(of: [srgb(1, 1, 1)], size: Self.stripeSize)

    let corrected = try ColorCorrector(correction: correction).apply(to: source)

    #expect(try stripeColor(0, in: corrected) == Raster.RGB(red: 255, green: 255, blue: 255))
  }

  @Test func sourceColorSpaceIsKept() throws {
    let source = try fixtures.stripes(
      of: [srgb(0.8, 0.2, 0.2)], size: Self.stripeSize, colorSpace: Palette.displayP3)

    let corrected = try ColorCorrector(correction: ColorCorrection(brightness: 2)).apply(to: source)

    #expect(corrected.colorSpace?.name == Palette.displayP3.name)
  }
}
