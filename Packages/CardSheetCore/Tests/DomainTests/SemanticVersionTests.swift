import Testing

@testable import Domain

@Suite struct SemanticVersionTests {
  private let expected = SemanticVersion(major: 1, minor: 2, patch: 3)

  @Test func parsesThreeNumericComponents() {
    #expect(SemanticVersion("1.2.3") == expected)
  }

  @Test func ignoresALeadingV() {
    #expect(SemanticVersion("v1.2.3") == expected)
  }

  @Test(arguments: [
    "1.2", "1.2.3-beta", "1.2.3.4", "+1.2.3", "-1.2.3", "a.b.c", "", "v", " 1.2.3", "1.2.3 ",
    "\u{0661}.\u{0662}.\u{0663}", "01.2.3", "1.02.3", "1.2.03", "V1.2.3", "vv1.2.3",
    "99999999999999999999.0.0", "0.99999999999999999999.0", "0.0.99999999999999999999",
  ])
  func rejectsAnythingButStrictNumbers(text: String) {
    #expect(SemanticVersion(text) == nil)
  }

  @Test func aLoneZeroIsAComponent() {
    #expect(SemanticVersion("0.0.0") == SemanticVersion(major: 0, minor: 0, patch: 0))
    #expect(SemanticVersion("10.20.30") == SemanticVersion(major: 10, minor: 20, patch: 30))
  }

  @Test func comparesComponentsAsNumbersNotText() {
    let nine = SemanticVersion(major: 0, minor: 9, patch: 0)
    let ten = SemanticVersion(major: 0, minor: 10, patch: 0)

    #expect(ten > nine)
  }

  @Test func majorOutweighsMinorAndPatch() {
    let older = SemanticVersion(major: 0, minor: 99, patch: 99)
    let newer = SemanticVersion(major: 1, minor: 0, patch: 0)

    #expect(older < newer)
  }

  @Test func patchBreaksTheTieOfEqualMinors() {
    let older = SemanticVersion(major: 1, minor: 2, patch: 3)
    let newer = SemanticVersion(major: 1, minor: 2, patch: 4)

    #expect(older < newer)
  }

  @Test func descriptionJoinsTheComponentsWithDots() {
    #expect(SemanticVersion(major: 0, minor: 7, patch: 0).description == "0.7.0")
  }
}
