import CoreGraphics
import Domain
import Foundation
import ImageIO

/// A decoded source image: a bitmap, or the first page of a PDF kept as vectors.
enum Artwork {
  case bitmap(CGImage)
  case vector(CGPDFPage)

  private static let rotatedOrientations: ClosedRange<Int> = 5...8

  /// Size as displayed, after the EXIF orientation is applied.
  static func displaySize(of image: ImageRef, at url: URL) throws(RenderError) -> PixelSize {
    if image.fileExtension.lowercased() == "pdf" {
      let box = try firstPDFPage(of: image, at: url).getBoxRect(.cropBox)
      return PixelSize(width: Int(box.width.rounded()), height: Int(box.height.rounded()))
    }
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int
    else { throw .unreadableImage(image) }
    let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
    return rotatedOrientations.contains(orientation)
      ? PixelSize(width: height, height: width) : PixelSize(width: width, height: height)
  }

  /// Decodes no more pixels than `maxPixelSize` on the longest side, to bound memory on large batches.
  static func load(_ image: ImageRef, at url: URL, maxPixelSize: Int) throws(RenderError) -> Artwork {
    if image.fileExtension.lowercased() == "pdf" {
      return .vector(try firstPDFPage(of: image, at: url))
    }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { throw .unreadableImage(image) }
    return .bitmap(bitmap)
  }

  private static func firstPDFPage(of image: ImageRef, at url: URL) throws(RenderError) -> CGPDFPage {
    guard let page = CGPDFDocument(url as CFURL)?.page(at: 1) else { throw .unreadableImage(image) }
    return page
  }

  /// Draws into `rect` (context units, y growing downward) without flipping the artwork.
  func draw(in rect: CGRect, context: CGContext) {
    context.saveGState()
    defer { context.restoreGState() }
    context.translateBy(x: rect.minX, y: rect.maxY)
    context.scaleBy(x: 1, y: -1)
    switch self {
    case .bitmap(let image):
      context.interpolationQuality = .high
      context.draw(image, in: CGRect(origin: .zero, size: rect.size))
    case .vector(let page):
      let box = page.getBoxRect(.cropBox)
      context.scaleBy(x: rect.width / box.width, y: rect.height / box.height)
      context.translateBy(x: -box.minX, y: -box.minY)
      context.drawPDFPage(page)
    }
  }
}
