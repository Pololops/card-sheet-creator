import Testing

@testable import Domain

@Suite struct DisplayScaleTests {
  @Test func builtInDisplayGivesPointsPerMillimetre() throws {
    let scale = try #require(DisplayScale.pointsPerMillimetre(physicalWidthMm: 302, widthPoints: 1512))

    #expect(abs(scale - 5.0066) < 0.001)
  }

  @Test(arguments: [0.0, 40.0, 3000.0])
  func implausiblePhysicalWidthIsUnknown(physicalWidthMm: Double) {
    #expect(DisplayScale.pointsPerMillimetre(physicalWidthMm: physicalWidthMm, widthPoints: 1512) == nil)
  }
}
