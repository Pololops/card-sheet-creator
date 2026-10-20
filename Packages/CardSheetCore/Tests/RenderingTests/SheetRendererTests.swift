import CoreGraphics
import Domain
import Foundation
import Testing

@testable import Rendering

@Suite struct SheetRendererTests {
  /// First slot of a standard-card 3 × 3 sheet: x 22…76, y 18.1…103.7 mm; second slot starts at x 78.
  private let standard = SheetGeometry(slot: .standardCard)
  private let fixtures: ImageFixtures

  init() throws {
    fixtures = try ImageFixtures()
  }

  private func render(_ pages: [RenderPage], images: [String: URL]) async throws -> PDFInspector {
    let output = fixtures.directory.appendingPathComponent("\(UUID().uuidString).pdf")
    let renderer = SheetRenderer(imageURL: { images[$0.sha256] ?? URL(fileURLWithPath: "/missing") })
    try await renderer.renderPDF(pages, to: output)
    return try PDFInspector(url: output)
  }

  private func solid(_ name: String, _ color: CGColor, width: Int = 540, height: Int = 856) throws -> (
    ImageRef, URL
  ) {
    let url = try fixtures.bitmap(named: name, width: width, height: height, left: color, right: color)
    return (ImageRef(sha256: name, fileExtension: "png"), url)
  }

  @Test func pageIsA4InPoints() async throws {
    let (red, url) = try solid("red.png", Palette.red)

    let pdf = try await render([RenderPage(geometry: standard, contents: [red])], images: [red.sha256: url])

    #expect(abs(pdf.mediaBox().width - 595.276) < 0.01)
    #expect(abs(pdf.mediaBox().height - 841.89) < 0.01)
  }

  @Test func oneSheetIsOnePage() async throws {
    let (red, url) = try solid("red.png", Palette.red)
    let page = RenderPage(geometry: standard, contents: [red])

    let pdf = try await render([page, page], images: [red.sha256: url])

    #expect(pdf.pageCount == 2)
  }

  @Test func slotShowsItsImage() async throws {
    let (red, url) = try solid("red.png", Palette.red)

    let raster = try await render(
      [RenderPage(geometry: standard, contents: [red])], images: [red.sha256: url]
    ).raster()

    #expect(raster.color(atMm: 49, 60).isRed)
  }

  @Test func gutterAndPageMarginStayWhite() async throws {
    let (red, url) = try solid("red.png", Palette.red)
    let contents = Array(repeating: Optional(red), count: 9)

    let raster = try await render(
      [RenderPage(geometry: standard, contents: contents)], images: [red.sha256: url]
    )
    .raster()

    #expect(raster.color(atMm: 77, 60).isWhite)
    #expect(raster.color(atMm: 10, 10).isWhite)
  }

  @Test func emptySlotPrintsNothingNotEvenAnOutline() async throws {
    let (red, url) = try solid("red.png", Palette.red)

    let raster = try await render(
      [RenderPage(geometry: standard, contents: [red, nil])], images: [red.sha256: url]
    )
    .raster()

    #expect(raster.color(atMm: 78.1, 60).isWhite)
    #expect(raster.color(atMm: 131.9, 60).isWhite)
    #expect(raster.color(atMm: 105, 18.2).isWhite)
  }

  @Test func wideImageCoversTheSlotWithoutBands() async throws {
    let (blue, url) = try solid("wide.png", Palette.blue, width: 3000, height: 1000)

    let raster = try await render(
      [RenderPage(geometry: standard, contents: [blue])], images: [blue.sha256: url]
    )
    .raster()

    #expect(raster.color(atMm: 49, 18.5).isBlue)
    #expect(raster.color(atMm: 49, 103.3).isBlue)
    #expect(raster.color(atMm: 22.3, 60).isBlue)
  }

  @Test(arguments: [(0.0, true), (1.0, false)])
  func anchorChoosesTheVisibleSideOfTheImage(anchorX: Double, showsLeftHalf: Bool) async throws {
    let url = try fixtures.bitmap(
      named: "halves.png", width: 2000, height: 1000, left: Palette.red, right: Palette.blue)
    let image = ImageRef(sha256: "halves", fileExtension: "png")
    let page = RenderPage(
      geometry: standard, contents: [image], crops: [image.sha256: CropAnchor(x: anchorX, y: 0.5)])

    let raster = try await render([page], images: [image.sha256: url]).raster()

    let center = raster.color(atMm: 49, 60)
    #expect(showsLeftHalf ? center.isRed : center.isBlue)
  }

  @Test func exifOrientationIsApplied() async throws {
    let url = try fixtures.bitmap(
      named: "camera.jpg", width: 1000, height: 600, left: Palette.red, right: Palette.blue, type: .jpeg,
      orientation: 6)
    let image = ImageRef(sha256: "camera", fileExtension: "jpg")

    let raster = try await render(
      [RenderPage(geometry: standard, contents: [image])], images: [image.sha256: url]
    )
    .raster()

    #expect(raster.color(atMm: 49, 35).isRed)
    #expect(raster.color(atMm: 49, 90).isBlue)
  }

  @Test func pdfSourceUsesItsFirstPage() async throws {
    let url = try fixtures.pdf(named: "artwork.pdf", pageColors: [Palette.green, Palette.red])
    let image = ImageRef(sha256: "artwork", fileExtension: "pdf")

    let raster = try await render(
      [RenderPage(geometry: standard, contents: [image])], images: [image.sha256: url]
    )
    .raster()

    #expect(raster.color(atMm: 49, 60).isGreen)
  }

  @Test func sourceColorSpaceIsPreserved() async throws {
    let url = try fixtures.bitmap(
      named: "p3.png", width: 540, height: 856, left: Palette.red, right: Palette.red,
      colorSpace: Palette.displayP3)
    let image = ImageRef(sha256: "p3", fileExtension: "png")

    let pdf = try await render(
      [RenderPage(geometry: standard, contents: [image])], images: [image.sha256: url])

    #expect(pdf.firstImageICCProfile() == Palette.displayP3.copyICCData() as Data?)
  }

  @Test func pageThumbnailHasA4ProportionsAndShowsTheImage() throws {
    let (red, url) = try solid("red.png", Palette.red)
    let renderer = SheetRenderer(imageURL: { _ in url })

    let thumbnail = try renderer.renderImage(
      RenderPage(geometry: standard, contents: [red]), widthPixels: 210)

    #expect(thumbnail.width == 210 && thumbnail.height == 297)
    let raster = try Raster(image: thumbnail, pixelsPerMillimetre: 1)
    #expect(raster.color(atMm: 49, 60).isRed)
    #expect(raster.color(atMm: 10, 10).isWhite)
  }

  @Test func missingImageFileFailsTheRender() async throws {
    let ghost = ImageRef(sha256: "ghost", fileExtension: "png")

    await #expect(throws: RenderError.unreadableImage(ghost)) {
      try await render([RenderPage(geometry: standard, contents: [ghost])], images: [:])
    }
  }
}
