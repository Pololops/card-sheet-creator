import Testing

@testable import CardSheetCreator

@MainActor @Suite struct CanvasZoomTests {
  @Test func pinchingScalesFromTheStartPercentage() {
    let zoom = CanvasZoom()

    let isAtLimit = zoom.magnify(from: 100, by: 1.5)

    #expect(zoom.mode == .custom(percent: 150))
    #expect(!isAtLimit)
  }

  @Test func pinchingStopsAtTheLargestZoom() {
    let zoom = CanvasZoom()

    let isAtLimit = zoom.magnify(from: 300, by: 2)

    #expect(zoom.mode == .custom(percent: 400))
    #expect(isAtLimit)
  }

  @Test func pinchingStopsAtTheSmallestZoom() {
    let zoom = CanvasZoom()

    let isAtLimit = zoom.magnify(from: 50, by: 0.25)

    #expect(zoom.mode == .custom(percent: 25))
    #expect(isAtLimit)
  }
}
