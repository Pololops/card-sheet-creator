import Foundation
import Testing

@testable import Rendering

@Suite struct CalibrationPageTests {
  private func render() async throws -> PDFInspector {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
    try await CalibrationPage.renderPDF(to: url)
    return try PDFInspector(url: url)
  }

  @Test func calibrationIsOneA4Page() async throws {
    let pdf = try await render()

    #expect(pdf.pageCount == 1)
    #expect(abs(pdf.mediaBox().width - 595.276) < 0.01)
  }

  @Test func cardOutlineSitsWhereTheFirstStandardSlotPrints() async throws {
    let raster = try await render().raster()

    #expect(!raster.color(atMm: 22, 60).isWhite)
    #expect(!raster.color(atMm: 76, 60).isWhite)
    #expect(raster.color(atMm: 49, 60).isWhite)
  }
}
