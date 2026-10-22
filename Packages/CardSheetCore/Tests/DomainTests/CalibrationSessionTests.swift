import Testing

@testable import Domain

@Suite struct CalibrationSessionTests {
  private func variant(_ letter: Character, of round: CalibrationRound) throws -> ChartVariant {
    try #require(round.variants.first { $0.letter == letter })
  }

  @Test func linearRoundRunsFromAToGWithDNeutral() {
    let variants = CalibrationRound.brightness.variants

    #expect(variants.map(\.letter) == Array("ABCDEFG"))
    #expect(variants.map(\.offset.brightness) == [-3, -2, -1, 0, 1, 2, 3])
    #expect(CalibrationRound.brightness.neutralVariant.letter == "D")
    #expect(CalibrationRound.brightness.neutralVariant.offset.isNeutral)
  }

  @Test func dominantGridIsWarmerOnTopAndMoreMagentaOnTheRight() {
    let variants = CalibrationRound.dominant.variants

    #expect(variants.map(\.letter) == Array("ABCDEFGHI"))
    #expect(variants.map(\.offset.warmth) == [1, 1, 1, 0, 0, 0, -1, -1, -1])
    #expect(variants.map(\.offset.tint) == [-1, 0, 1, -1, 0, 1, -1, 0, 1])
    #expect(CalibrationRound.dominant.neutralVariant.letter == "E")
    #expect(CalibrationRound.dominant.columnCount == 3)
    #expect(CalibrationRound.brightness.columnCount == 7)
  }

  @Test func blackAndWhitePrinterGetsBrightnessAndContrastOnly() {
    #expect(CalibrationRound.rounds(isColorPrinter: false) == [.brightness, .contrast])
    #expect(
      CalibrationRound.rounds(isColorPrinter: true) == [.brightness, .contrast, .dominant, .saturation])
  }

  @Test func pickAddsThePrintedOffsetWithoutInversion() throws {
    var session = CalibrationSession(rounds: [.brightness], startingFrom: .neutral)

    session.pick(try variant("F", of: .brightness))

    #expect(session.result == ColorCorrection(brightness: 2))
  }

  @Test func centreIsClampedSoEveryVariantStaysWithinLimits() throws {
    var session = CalibrationSession(
      rounds: [.brightness], startingFrom: ColorCorrection(brightness: 5, warmth: 2))

    session.pick(try variant("G", of: .brightness))

    #expect(session.centre == ColorCorrection(brightness: 3, warmth: 1))
    #expect(session.result.brightness == 6)
  }

  @Test func picksFollowTheRoundOrderUntilComplete() throws {
    var session = CalibrationSession(rounds: [.brightness, .contrast], startingFrom: .neutral)
    #expect(session.currentRound == .brightness)

    session.pick(try variant("E", of: .brightness))
    #expect(session.currentRound == .contrast)
    #expect(!session.isComplete)

    session.pick(try variant("B", of: .contrast))

    #expect(session.currentRound == nil)
    #expect(session.isComplete)
    #expect(session.result == ColorCorrection(brightness: 1, contrast: -2))
  }

  @Test func pickFromAnotherRoundIsIgnored() throws {
    var session = CalibrationSession(rounds: [.brightness, .contrast], startingFrom: .neutral)

    session.pick(try variant("G", of: .contrast))

    #expect(session.currentRound == .brightness)
    #expect(session.picks.isEmpty)
  }

  @Test func pickAfterCompletionIsIgnored() throws {
    var session = CalibrationSession(rounds: [.brightness], startingFrom: .neutral)
    session.pick(try variant("E", of: .brightness))

    session.pick(try variant("G", of: .brightness))

    #expect(session.result == ColorCorrection(brightness: 1))
  }

  @Test func undoReopensTheLastRound() throws {
    var session = CalibrationSession(rounds: [.brightness, .contrast], startingFrom: .neutral)
    session.pick(try variant("E", of: .brightness))
    session.pick(try variant("B", of: .contrast))

    session.undoLastPick()

    #expect(session.currentRound == .contrast)
    #expect(!session.isComplete)
    #expect(session.result == ColorCorrection(brightness: 1))
  }

  @Test func undoWithoutPicksChangesNothing() {
    var session = CalibrationSession(rounds: [.brightness], startingFrom: .neutral)

    session.undoLastPick()

    #expect(session.picks.isEmpty)
    #expect(session.currentRound == .brightness)
  }
}
