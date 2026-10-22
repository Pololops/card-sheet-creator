import CoreGraphics
import Domain
import Foundation

/// Turns sheets into an A4 PDF at exact size. Saved and previewed PDFs show the artwork as it is; the one
/// sent to a printer can carry a `ColorCorrection` (ADR 0012), which never changes sizes or layout.
public struct SheetRenderer: Sendable {
  public static let printResolution = 600.0
  public static let previewResolution = 150.0
  private static let millimetresPerInch = 25.4

  private let imageURL: @Sendable (ImageRef) -> URL
  private let resolution: Double

  public init(imageURL: @escaping @Sendable (ImageRef) -> URL, resolution: Double = printResolution) {
    self.imageURL = imageURL
    self.resolution = resolution
  }

  @concurrent
  public func renderPDF(
    _ pages: [RenderPage], to url: URL, correction: ColorCorrection = .neutral
  ) async throws(RenderError) {
    var mediaBox = CGRect(x: 0, y: 0, width: Page.a4.width.points, height: Page.a4.height.points)
    guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
      throw .cannotCreateDocument
    }
    defer { context.closePDF() }
    let corrector = correction.isNeutral ? nil : ColorCorrector(correction: correction)
    for page in pages {
      context.beginPDFPage(nil)
      defer { context.endPDFPage() }
      try autoreleasepool { () throws(RenderError) in try draw(page, in: context, corrector: corrector) }
    }
  }

  /// Draws one page in a context whose user space is the A4 page in points, origin bottom-left.
  func draw(_ page: RenderPage, in context: CGContext, corrector: ColorCorrector? = nil) throws(RenderError) {
    let layout: GridLayout
    do {
      layout = try GridLayout.make(page.geometry)
    } catch {
      throw .invalidLayout(error)
    }
    let pointsPerMillimetre = Millimeters(mm: 1).points

    context.saveGState()
    defer { context.restoreGState() }
    context.translateBy(x: 0, y: Page.a4.height.points)
    context.scaleBy(x: pointsPerMillimetre, y: -pointsPerMillimetre)

    var decoded: [String: (Artwork, PixelSize)] = [:]
    for (slot, image) in zip(layout.slots, page.contents) {
      guard let image else { continue }
      let (artwork, size) = try decodedArtwork(image, page: page, corrector: corrector, cache: &decoded)
      let cover = Crop.coverRect(
        image: size, slot: page.geometry.slot, anchor: page.crops[image.sha256] ?? .centered)

      context.saveGState()
      context.clip(to: CGRect(x: slot.x, y: slot.y, width: slot.width, height: slot.height))
      artwork.draw(
        in: CGRect(x: slot.x + cover.x, y: slot.y + cover.y, width: cover.width, height: cover.height),
        context: context)
      context.restoreGState()
    }
  }

  /// Clones of an image on the same page are decoded once. Under a correction every artwork becomes a
  /// bitmap at print resolution, PDF artwork included, because a colour lookup can't act on vectors.
  private func decodedArtwork(
    _ image: ImageRef, page: RenderPage, corrector: ColorCorrector?,
    cache: inout [String: (Artwork, PixelSize)]
  ) throws(RenderError) -> (Artwork, PixelSize) {
    if let cached = cache[image.sha256] { return cached }
    let url = imageURL(image)
    let size = try Artwork.displaySize(of: image, at: url)
    let cover = Crop.coverRect(
      image: size, slot: page.geometry.slot, anchor: page.crops[image.sha256] ?? .centered)
    let artwork: Artwork
    if let corrector {
      let bitmap = try Thumbnails.image(of: image, at: url, maxPixelSize: pixels(for: cover))
      artwork = .bitmap(try corrector.apply(to: bitmap))
    } else {
      artwork = try Artwork.load(image, at: url, maxPixelSize: pixels(for: cover))
    }
    cache[image.sha256] = (artwork, size)
    return (artwork, size)
  }

  private func pixels(for cover: MMRect) -> Int {
    Int((max(cover.width, cover.height) / Self.millimetresPerInch * resolution).rounded(.up))
  }
}
