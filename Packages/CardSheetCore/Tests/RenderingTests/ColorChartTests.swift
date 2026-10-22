import CoreGraphics
import Domain
import Foundation
import Testing

@testable import Rendering

@Suite struct ColorChartTests {
  private static let allRounds = CalibrationRound.allCases
  private static let screenTolerance = 3

  private func temporaryPDF() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
  }

  private func chartRaster(
    centre: ColorCorrection = .neutral, rounds: [CalibrationRound] = CalibrationRound.allCases
  ) async throws -> Raster {
    let url = temporaryPDF()
    try await ColorChart.renderPDF(to: url, centre: centre, rounds: rounds)
    return try PDFInspector(url: url).raster()
  }

  private func verificationRaster(correction: ColorCorrection) async throws -> Raster {
    let url = temporaryPDF()
    try await ColorChart.renderVerificationPDF(to: url, correction: correction, rounds: Self.allRounds)
    return try PDFInspector(url: url).raster()
  }

  private func patch(_ round: CalibrationRound, _ letter: Character) throws -> CGRect {
    try #require(
      ChartLayout.patches(for: Self.allRounds).first { $0.round == round && $0.variant.letter == letter }
    ).rect
  }

  /// The colour at a fraction of a patch, measured down and right from its top-left corner.
  private func color(in raster: Raster, of rect: CGRect, at fraction: (x: Double, y: Double)) -> Raster.RGB {
    raster.color(atMm: rect.minX + fraction.x * rect.width, rect.minY + fraction.y * rect.height)
  }

  private func isClose(_ first: Raster.RGB, _ second: Raster.RGB) -> Bool {
    [(first.red, second.red), (first.green, second.green), (first.blue, second.blue)]
      .allSatisfy { abs(Int($0) - Int($1)) <= Self.screenTolerance }
  }

  @Test func brightnessRowDarkensTowardsA() async throws {
    let raster = try await chartRaster()
    let topBand = (x: 0.5, y: 0.1)

    let darkest = color(in: raster, of: try patch(.brightness, "A"), at: topBand)
    let lightest = color(in: raster, of: try patch(.brightness, "G"), at: topBand)

    #expect(darkest.red < lightest.red)
  }

  @Test func dominantTopRowIsWarmer() async throws {
    let raster = try await chartRaster()
    let background = (x: 0.1, y: 0.1)

    let warmer = color(in: raster, of: try patch(.dominant, "B"), at: background)
    let cooler = color(in: raster, of: try patch(.dominant, "H"), at: background)

    #expect(Int(warmer.red) - Int(warmer.blue) > Int(cooler.red) - Int(cooler.blue))
  }

  @Test(arguments: CalibrationRound.allCases)
  func paperDMatchesTheScreenReference(round: CalibrationRound) async throws {
    let raster = try await chartRaster()
    let reference = try Raster(
      image: ColorChart.referenceImage(for: round), pixelsPerMillimetre: 1)
    let probe = (x: 0.2, y: 0.2)
    let paper = color(
      in: raster, of: try patch(round, round.neutralVariant.letter), at: probe)

    let screen = reference.color(
      atMm: probe.x * Double(reference.width), probe.y * Double(reference.width))

    #expect(isClose(paper, screen))
  }

  @Test func chartCarriesTheCurrentCorrection() async throws {
    let plain = try await chartRaster()
    let brightened = try await chartRaster(centre: ColorCorrection(brightness: 2))
    let paperD = try patch(.brightness, "D")
    let topBand = (x: 0.5, y: 0.1)

    let before = color(in: plain, of: paperD, at: topBand)
    let after = color(in: brightened, of: paperD, at: topBand)

    #expect(after.red > before.red + 10)
  }

  @Test func blackAndWhiteChartHasNoColourRounds() async throws {
    let rounds: [CalibrationRound] = [.brightness, .contrast]
    let placed = ChartLayout.patches(for: rounds)

    let raster = try await chartRaster(rounds: rounds)

    #expect(Set(placed.map(\.round)) == Set(rounds))
    #expect(raster.color(atMm: 78, 131).isWhite)
  }

  @Test func everyPatchStaysInsideTheSafetyBox() {
    let box = CGRect(
      x: Page.safetyMargin.mm, y: Page.safetyMargin.mm,
      width: Page.a4.width.mm - 2 * Page.safetyMargin.mm,
      height: Page.a4.height.mm - 2 * Page.safetyMargin.mm)
    let rects =
      ChartLayout.patches(for: Self.allRounds).map(\.rect)
      + ChartLayout.verificationRects(for: Self.allRounds).map(\.rect)

    #expect(rects.allSatisfy { box.contains($0) })
  }

  @Test func verificationPageShowsCorrectedReferences() async throws {
    let rect = try #require(
      ChartLayout.verificationRects(for: Self.allRounds).first { $0.round == .brightness }
    ).rect
    let probe = (x: 0.5, y: 0.1)

    let plain = color(in: try await verificationRaster(correction: .neutral), of: rect, at: probe)
    let corrected = color(
      in: try await verificationRaster(correction: ColorCorrection(brightness: 4)), of: rect, at: probe)

    #expect(corrected.red > plain.red + 10)
  }
}
