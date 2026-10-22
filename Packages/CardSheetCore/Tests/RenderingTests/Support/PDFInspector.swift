import CoreGraphics
import Foundation

/// Reads back a rendered PDF the way a printer would see it.
struct PDFInspector {
  private static let pixelsPerMillimetre = 4.0

  let document: CGPDFDocument

  init(url: URL) throws {
    guard let document = CGPDFDocument(url as CFURL) else { throw FixtureError.cannotDraw }
    self.document = document
  }

  var pageCount: Int { document.numberOfPages }

  func mediaBox(page: Int = 1) -> CGRect {
    document.page(at: page)?.getBoxRect(.mediaBox) ?? .zero
  }

  /// Rasterizes a page so colours can be sampled at millimetre coordinates (origin top-left).
  func raster(page: Int = 1) throws -> Raster {
    guard let pdfPage = document.page(at: page) else { throw FixtureError.cannotDraw }
    let box = pdfPage.getBoxRect(.mediaBox)
    let scale = Self.pixelsPerMillimetre * 25.4 / 72
    let width = Int(box.width * scale)
    let height = Int(box.height * scale)
    guard
      let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: Palette.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw FixtureError.cannotDraw }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.scaleBy(x: scale, y: scale)
    context.drawPDFPage(pdfPage)
    guard let data = context.data else { throw FixtureError.cannotDraw }
    let bytes = Array(
      UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: width * height * 4))
    return Raster(bytes: bytes, width: width, pixelsPerMillimetre: Self.pixelsPerMillimetre)
  }

  /// The ICC profile of the first image drawn on the page.
  func firstImageICCProfile(page: Int = 1) -> Data? {
    guard let image = firstImageDictionary(page: page) else { return nil }
    var colorSpace: CGPDFArrayRef?
    var iccStream: CGPDFStreamRef?
    guard CGPDFDictionaryGetArray(image, "ColorSpace", &colorSpace), let colorSpace,
      CGPDFArrayGetStream(colorSpace, 1, &iccStream), let iccStream
    else { return nil }
    var format = CGPDFDataFormat.raw
    return CGPDFStreamCopyData(iccStream, &format) as Data?
  }

  /// The pixel width of the first image drawn on the page; `nil` when the page holds no bitmap, as for
  /// artwork kept as vectors.
  func firstImagePixelWidth(page: Int = 1) -> Int? {
    guard let image = firstImageDictionary(page: page) else { return nil }
    var width: CGPDFInteger = 0
    return CGPDFDictionaryGetInteger(image, "Width", &width) ? width : nil
  }

  /// The first XObject that is a bitmap (only images carry a pixel `Width`).
  private func firstImageDictionary(page: Int) -> CGPDFDictionaryRef? {
    guard let dictionary = document.page(at: page)?.dictionary else { return nil }
    var resources: CGPDFDictionaryRef?
    var xObjects: CGPDFDictionaryRef?
    guard CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources), let resources,
      CGPDFDictionaryGetDictionary(resources, "XObject", &xObjects), let xObjects
    else { return nil }

    var image: CGPDFDictionaryRef?
    CGPDFDictionaryApplyBlock(
      xObjects,
      { _, object, _ in
        var stream: CGPDFStreamRef?
        var width: CGPDFInteger = 0
        guard CGPDFObjectGetValue(object, .stream, &stream), let stream,
          let candidate = CGPDFStreamGetDictionary(stream),
          CGPDFDictionaryGetInteger(candidate, "Width", &width)
        else { return true }
        image = candidate
        return false
      }, nil)
    return image
  }
}

struct Raster {
  struct RGB: Equatable {
    var red: UInt8
    var green: UInt8
    var blue: UInt8

    var isWhite: Bool { red > 245 && green > 245 && blue > 245 }
    var isRed: Bool { red > 200 && green < 60 && blue < 60 }
    var isBlue: Bool { blue > 200 && red < 60 && green < 60 }
    var isGreen: Bool { green > 200 && red < 60 && blue < 60 }
  }

  let bytes: [UInt8]
  let width: Int
  let pixelsPerMillimetre: Double

  init(bytes: [UInt8], width: Int, pixelsPerMillimetre: Double) {
    self.bytes = bytes
    self.width = width
    self.pixelsPerMillimetre = pixelsPerMillimetre
  }

  /// Redraws `image` into a known RGBA layout so its pixels can be sampled.
  init(image: CGImage, pixelsPerMillimetre: Double) throws {
    guard
      let context = CGContext(
        data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
        bytesPerRow: image.width * 4,
        space: Palette.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw FixtureError.cannotDraw }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let data = context.data else { throw FixtureError.cannotDraw }
    bytes = Array(
      UnsafeBufferPointer(
        start: data.assumingMemoryBound(to: UInt8.self), count: image.width * image.height * 4))
    width = image.width
    self.pixelsPerMillimetre = pixelsPerMillimetre
  }

  func color(atMm x: Double, _ y: Double) -> RGB {
    let column = Int(x * pixelsPerMillimetre)
    let row = Int(y * pixelsPerMillimetre)
    let offset = (row * width + column) * 4
    return RGB(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2])
  }
}
