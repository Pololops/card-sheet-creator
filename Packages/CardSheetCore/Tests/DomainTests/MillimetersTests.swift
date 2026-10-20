import Testing

@testable import Domain

@Suite struct MillimetersTests {
  @Test func oneInchIsSeventyTwoPoints() {
    #expect(abs(Millimeters(mm: 25.4).points - 72) < 0.0001)
  }

  @Test func decimalMillimetresAreStoredAsExactTenths() {
    #expect(Millimeters(mm: 85.6).tenths == 856)
  }

  @Test func a4PageMatchesPostScriptPointSize() {
    #expect(abs(Page.a4.width.points - 595.276) < 0.001)
    #expect(abs(Page.a4.height.points - 841.89) < 0.001)
  }
}
