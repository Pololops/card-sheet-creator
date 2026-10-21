import Domain

/// Says in plain words what the printer does wrong, which is the opposite of what the correction does:
/// a correction that brightens means the printer darkens.
enum CorrectionDiagnosis {
  static func sentence(for correction: ColorCorrection) -> String {
    let tendencies = tendencies(of: correction)
    guard !tendencies.isEmpty else {
      return "Ton imprimante reproduit déjà fidèlement l'écran : aucune correction."
    }
    return "Ton imprimante \(joined(tendencies)) : on compense."
  }

  private static func tendencies(of correction: ColorCorrection) -> [String] {
    [
      levelTendency(
        correction.brightness, positive: "assombrit", negative: "éclaircit", object: "les images"),
      levelTendency(correction.contrast, positive: "adoucit", negative: "durcit", object: "les contrastes"),
      levelTendency(correction.saturation, positive: "pâlit", negative: "avive", object: "les couleurs"),
      castTendency(warmth: correction.warmth, tint: correction.tint),
    ].compactMap { $0 }
  }

  private static func levelTendency(_ level: Int, positive: String, negative: String, object: String)
    -> String?
  {
    guard level != 0 else { return nil }
    let verb = level > 0 ? positive : negative
    return [verb, levelAdverb(magnitude: abs(level)), object].compactMap { $0 }.joined(separator: " ")
  }

  private static func levelAdverb(magnitude: Int) -> String? {
    switch magnitude {
    case ...2: "un peu"
    case 3...4: nil
    default: "nettement"
    }
  }

  private static func castTendency(warmth: Int, tint: Int) -> String? {
    guard let colour = castColour(warmth: warmth, tint: tint) else { return nil }
    let adverb = max(abs(warmth), abs(tint)) == 1 ? "un peu" : nil
    return ["tire", adverb, "vers", colour].compactMap { $0 }.joined(separator: " ")
  }

  /// The colour the print drifts to, from the correction's signs: warmer fixes a blue drift, more magenta
  /// fixes a green one.
  private static func castColour(warmth: Int, tint: Int) -> String? {
    switch (warmth.signum(), tint.signum()) {
    case (1, 0): "le bleu"
    case (-1, 0): "le jaune"
    case (0, 1): "le vert"
    case (0, -1): "le rose"
    case (1, 1): "le bleu-vert"
    case (1, -1): "le violet"
    case (-1, 1): "le jaune-vert"
    case (-1, -1): "l'orangé"
    default: nil
    }
  }

  private static func joined(_ tendencies: [String]) -> String {
    guard tendencies.count > 1, let last = tendencies.last else { return tendencies.joined() }
    return tendencies.dropLast().joined(separator: ", ") + " et " + last
  }
}
