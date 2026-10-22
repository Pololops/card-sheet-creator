import Domain

/// One line of "Ce qu'on compense": an axis of the correction, which way it was moved and by how many steps.
struct CorrectionReading: Identifiable, Equatable {
  let name: String
  let lowEnd: String
  let highEnd: String
  let steps: Int
  let limit: Int

  var id: String { name }

  var value: String {
    guard steps != 0 else { return "Aucune correction" }
    let direction = steps > 0 ? highEnd : lowEnd
    return "\(direction) · \(abs(steps)) \(abs(steps) > 1 ? "crans" : "cran")"
  }

  /// A black-and-white printer was only asked about levels, so colour axes would show a meaningless zero.
  static func readings(for correction: ColorCorrection, isColorPrinter: Bool) -> [CorrectionReading] {
    let levels = [
      CorrectionReading(
        name: "Luminosité", lowEnd: "Assombrir", highEnd: "Éclaircir", steps: correction.brightness,
        limit: ColorCorrection.levelLimit),
      CorrectionReading(
        name: "Contraste", lowEnd: "Adoucir", highEnd: "Renforcer", steps: correction.contrast,
        limit: ColorCorrection.levelLimit),
    ]
    guard isColorPrinter else { return levels }
    return levels + [
      CorrectionReading(
        name: "Chaud ou froid", lowEnd: "Refroidir", highEnd: "Réchauffer", steps: correction.warmth,
        limit: ColorCorrection.dominantLimit),
      CorrectionReading(
        name: "Vert ou rose", lowEnd: "Plus vert", highEnd: "Plus rose", steps: correction.tint,
        limit: ColorCorrection.dominantLimit),
      CorrectionReading(
        name: "Intensité", lowEnd: "Pâlir", highEnd: "Aviver", steps: correction.saturation,
        limit: ColorCorrection.levelLimit),
    ]
  }
}
