/// The picks made so far in a calibration. Patches were printed around `centre`, so the answer is the
/// centre plus what each pick moved: no inversion is involved, the user chose what already looks right.
public struct CalibrationSession: Hashable, Sendable {
  public let rounds: [CalibrationRound]
  /// The correction every printed patch is offset from, pulled in so no patch is clamped to its neighbour.
  public let centre: ColorCorrection
  public private(set) var picks: [ChartVariant] = []

  public init(rounds: [CalibrationRound], startingFrom start: ColorCorrection) {
    self.rounds = rounds
    centre = start.clamped(
      levelLimit: ColorCorrection.levelLimit - CalibrationRound.linearReach,
      dominantLimit: ColorCorrection.dominantLimit - CalibrationRound.dominantReach)
  }

  public var currentRound: CalibrationRound? {
    picks.count < rounds.count ? rounds[picks.count] : nil
  }

  public var isComplete: Bool { currentRound == nil }

  public var result: ColorCorrection {
    picks.reduce(centre) { $0.adding($1.offset) }
  }

  /// A variant that does not belong to the current round is ignored.
  public mutating func pick(_ variant: ChartVariant) {
    guard let round = currentRound, round.variants.contains(variant) else { return }
    picks.append(variant)
  }
}
