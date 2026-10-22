import Domain
import Testing

@testable import Rendering

private let extremeCorrections: [ColorCorrection] = {
  let level = ColorCorrection.levelLimit
  let dominant = ColorCorrection.dominantLimit
  let singleFields = [-1, 1].flatMap { sign in
    [
      ColorCorrection(brightness: sign * level),
      ColorCorrection(contrast: sign * level),
      ColorCorrection(saturation: sign * level),
      ColorCorrection(warmth: sign * dominant),
      ColorCorrection(tint: sign * dominant),
      ColorCorrection(
        brightness: sign * level, contrast: sign * level, saturation: sign * level, warmth: sign * dominant,
        tint: sign * dominant),
    ]
  }
  let mixedSigns = ColorCorrection(
    brightness: level, contrast: -level, saturation: level, warmth: -dominant, tint: dominant)
  return singleFields + [mixedSigns]
}()

@Suite struct CorrectionCurveTests {
  private let midGrey = SIMD3(repeating: 0.5)

  private func apply(_ correction: ColorCorrection, to value: SIMD3<Double>) -> SIMD3<Double> {
    CorrectionCurve.apply(value, correction)
  }

  @Test(arguments: extremeCorrections)
  func whiteAndBlackStayFixed(correction: ColorCorrection) {
    #expect(apply(correction, to: SIMD3(repeating: 1)) == SIMD3(repeating: 1))
    #expect(apply(correction, to: SIMD3(repeating: 0)) == SIMD3(repeating: 0))
  }

  @Test func neutralIsIdentity() {
    let sample = SIMD3(0.2, 0.55, 0.9)

    let corrected = apply(.neutral, to: sample)

    #expect(abs(corrected.x - sample.x) < 1e-12)
    #expect(abs(corrected.y - sample.y) < 1e-12)
    #expect(abs(corrected.z - sample.z) < 1e-12)
  }

  @Test func brightnessRaisesMidGreyMonotonically() {
    let greys = (-6...6).map { apply(ColorCorrection(brightness: $0), to: midGrey).x }

    #expect(zip(greys, greys.dropFirst()).allSatisfy { $0 < $1 })
    #expect(abs(greys[6] - 0.5) < 1e-12)
  }

  @Test func brightnessKeepsNeutralsNeutral() {
    let corrected = apply(ColorCorrection(brightness: 4), to: midGrey)

    #expect(corrected.x == corrected.y && corrected.y == corrected.z)
  }

  @Test(arguments: [1, 3, 6])
  func contrastSpreadsQuartilesAndKeepsMidGrey(level: Int) {
    let more = ColorCorrection(contrast: level)
    let less = ColorCorrection(contrast: -level)

    #expect(abs(apply(more, to: midGrey).x - 0.5) < 1e-9)
    #expect(apply(more, to: SIMD3(repeating: 0.25)).x < 0.25)
    #expect(apply(more, to: SIMD3(repeating: 0.75)).x > 0.75)
    #expect(apply(less, to: SIMD3(repeating: 0.25)).x > 0.25)
    #expect(apply(less, to: SIMD3(repeating: 0.75)).x < 0.75)
  }

  @Test(arguments: extremeCorrections)
  func curveStaysMonotoneInInput(correction: ColorCorrection) {
    let ramp = (0...255).map { apply(correction, to: SIMD3(repeating: Double($0) / 255)) }

    for (lower, higher) in zip(ramp, ramp.dropFirst()) {
      #expect(lower.x <= higher.x && lower.y <= higher.y && lower.z <= higher.z)
    }
  }

  @Test func warmthRaisesRedOverBlue() {
    let warmer = apply(ColorCorrection(warmth: 2), to: midGrey)
    let cooler = apply(ColorCorrection(warmth: -2), to: midGrey)

    #expect(warmer.x > 0.5 && warmer.z < 0.5)
    #expect(cooler.x < 0.5 && cooler.z > 0.5)
  }

  @Test func tintLowersGreen() {
    let magenta = apply(ColorCorrection(tint: 2), to: midGrey)
    let green = apply(ColorCorrection(tint: -2), to: midGrey)

    #expect(magenta.y < 0.5)
    #expect(green.y > 0.5)
  }

  @Test func saturationWidensChroma() {
    let colour = SIMD3(0.8, 0.4, 0.4)
    let spread = { (value: SIMD3<Double>) in value.max() - value.min() }

    #expect(spread(apply(ColorCorrection(saturation: 3), to: colour)) > spread(colour))
    #expect(spread(apply(ColorCorrection(saturation: -3), to: colour)) < spread(colour))
    #expect(apply(ColorCorrection(saturation: 6), to: midGrey) == midGrey)
  }
}
