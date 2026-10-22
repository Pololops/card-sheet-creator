import Domain
import Foundation

/// What one step of each correction axis does to a colour. Every stage keeps black and white where they
/// are, so a correction never inks the paper's white or lifts its black.
///
/// The step sizes are tuned on a real printer and then frozen: changing one changes every saved
/// calibration, so it needs a new ADR.
enum CorrectionCurve {
  private static let castGammaStep = 1.08
  private static let brightnessGammaStep = 1.1
  private static let contrastStep = 0.1
  private static let saturationStep = 0.1
  /// Rec. 709 luma weights; the red weight is what remains of 1.
  private static let greenLuma = 0.7152
  private static let blueLuma = 0.0722

  /// `rgb` and the result are encoded (not linear) values in 0...1.
  static func apply(_ rgb: SIMD3<Double>, _ correction: ColorCorrection) -> SIMD3<Double> {
    let cast = applyCast(rgb, warmth: correction.warmth, tint: correction.tint)
    let brightened = applyBrightness(cast, level: correction.brightness)
    let contrasted = applyContrast(brightened, level: correction.contrast)
    let saturated = applySaturation(contrasted, level: correction.saturation)
    return saturated.clamped(lowerBound: .zero, upperBound: SIMD3(repeating: 1))
  }

  /// A power per channel: warmer lifts red and sinks blue, magenta sinks green.
  private static func applyCast(_ rgb: SIMD3<Double>, warmth: Int, tint: Int) -> SIMD3<Double> {
    let exponents = SIMD3(
      pow(castGammaStep, -Double(warmth)), pow(castGammaStep, Double(tint)),
      pow(castGammaStep, Double(warmth)))
    return SIMD3(pow(rgb.x, exponents.x), pow(rgb.y, exponents.y), pow(rgb.z, exponents.z))
  }

  /// A power curve moves mid-tones the most, and neutral greys stay neutral.
  private static func applyBrightness(_ rgb: SIMD3<Double>, level: Int) -> SIMD3<Double> {
    let exponent = pow(brightnessGammaStep, -Double(level))
    return SIMD3(pow(rgb.x, exponent), pow(rgb.y, exponent), pow(rgb.z, exponent))
  }

  /// `x - a·sin(2πx)/2π` pivots on mid-grey with slope `1 + a` there, and stays monotone while |a| < 1.
  private static func applyContrast(_ rgb: SIMD3<Double>, level: Int) -> SIMD3<Double> {
    let amount = contrastStep * Double(level)
    func curve(_ value: Double) -> Double { value - amount * sin(2 * .pi * value) / (2 * .pi) }
    return SIMD3(curve(rgb.x), curve(rgb.y), curve(rgb.z))
  }

  /// Luma is red plus weighted differences, so a grey has exactly zero chroma and white stays exactly white.
  private static func applySaturation(_ rgb: SIMD3<Double>, level: Int) -> SIMD3<Double> {
    let luma = rgb.x + greenLuma * (rgb.y - rgb.x) + blueLuma * (rgb.z - rgb.x)
    let gain = 1 + saturationStep * Double(level)
    return luma + gain * (rgb - SIMD3(repeating: luma))
  }
}
