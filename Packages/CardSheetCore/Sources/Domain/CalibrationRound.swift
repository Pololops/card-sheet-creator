/// One printed patch of a round: a letter to name it and how far it is from the round's centre.
public struct ChartVariant: Hashable, Sendable {
  public let letter: Character
  public let offset: ColorCorrection

  public init(letter: Character, offset: ColorCorrection) {
    self.letter = letter
    self.offset = offset
  }
}

/// One "find the twin" question of the calibration: a row or grid of patches printed at steps around the
/// current correction, of which the user picks the one that looks like the screen.
public enum CalibrationRound: CaseIterable, Sendable {
  case brightness
  case contrast
  case dominant
  case saturation

  /// Steps either side of the centre in a linear round, and in each direction of the dominant grid.
  public static let linearReach = 3
  public static let dominantReach = 1

  private static let letters = Array("ABCDEFGHI")

  /// Black-and-white printers have no colour to compare, so they skip the colour rounds.
  public static func rounds(isColorPrinter: Bool) -> [CalibrationRound] {
    isColorPrinter ? allCases : [.brightness, .contrast]
  }

  public var title: String {
    switch self {
    case .brightness: "Luminosité"
    case .contrast: "Contraste"
    case .dominant: "Dominante"
    case .saturation: "Intensité des couleurs"
    }
  }

  public var columnCount: Int {
    self == .dominant ? 2 * Self.dominantReach + 1 : 2 * Self.linearReach + 1
  }

  /// Linear rounds run from A (lowest) to G; the dominant grid reads row by row, warmer on top and more
  /// magenta to the right.
  public var variants: [ChartVariant] {
    zip(Self.letters, offsets).map { ChartVariant(letter: $0, offset: $1) }
  }

  public var neutralVariant: ChartVariant {
    variants[variants.count / 2]
  }

  private var offsets: [ColorCorrection] {
    let steps = Array(-Self.linearReach...Self.linearReach)
    switch self {
    case .brightness: return steps.map { ColorCorrection(brightness: $0) }
    case .contrast: return steps.map { ColorCorrection(contrast: $0) }
    case .saturation: return steps.map { ColorCorrection(saturation: $0) }
    case .dominant:
      let reach = Self.dominantReach
      return (-reach...reach).reversed().flatMap { warmth in
        (-reach...reach).map { ColorCorrection(warmth: warmth, tint: $0) }
      }
    }
  }
}
