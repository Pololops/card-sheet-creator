import Testing

@testable import Domain

@Suite struct ColorCorrectionTests {
  @Test func addingClampsToTheStoredLimits() {
    let sum = ColorCorrection(brightness: 5, warmth: 2).adding(ColorCorrection(brightness: 3, warmth: 1))

    #expect(sum.brightness == 6)
    #expect(sum.warmth == 2)
  }

  @Test func addingClampsNegativeSumsToo() {
    let sum = ColorCorrection(contrast: -5, tint: -2).adding(ColorCorrection(contrast: -3, tint: -1))

    #expect(sum.contrast == -6)
    #expect(sum.tint == -2)
  }

  @Test func neutralHasNoEffectFlag() {
    #expect(ColorCorrection.neutral.isNeutral)
    #expect(!ColorCorrection(saturation: 1).isNeutral)
  }
}
