import CoreGraphics
import Domain
import Foundation

/// Bitmaps for the screen: library thumbnails and slot images in the sheet editor.
public enum Thumbnails {
  public static func displaySize(of image: ImageRef, at url: URL) throws(RenderError) -> PixelSize {
    try Artwork.displaySize(of: image, at: url)
  }

  public static func image(of image: ImageRef, at url: URL, maxPixelSize: Int) throws(RenderError) -> CGImage
  {
    switch try Artwork.load(image, at: url, maxPixelSize: maxPixelSize) {
    case .bitmap(let bitmap):
      return bitmap
    case .vector(let page):
      let box = page.getBoxRect(.cropBox)
      let scale = Double(maxPixelSize) / max(box.width, box.height)
      return try rasterize(width: Int(box.width * scale), height: Int(box.height * scale)) { context in
        Artwork.vector(page).draw(
          in: CGRect(x: 0, y: 0, width: box.width * scale, height: box.height * scale), context: context)
      }
    }
  }

  /// Draws `body` in a white bitmap whose user space is flipped (y grows downward), like the renderer's.
  static func rasterize(width: Int, height: Int, _ body: (CGContext) throws(RenderError) -> Void)
    throws(RenderError) -> CGImage
  {
    guard
      let context = CGContext(
        data: nil, width: max(width, 1), height: max(height, 1), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw .cannotCreateDocument }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.translateBy(x: 0, y: Double(height))
    context.scaleBy(x: 1, y: -1)
    try body(context)
    guard let image = context.makeImage() else { throw .cannotCreateDocument }
    return image
  }
}

extension SheetRenderer {
  /// A small bitmap of a whole page, for the sidebar and the print preview.
  public func renderImage(_ page: RenderPage, widthPixels: Int) throws(RenderError) -> CGImage {
    let scale = Double(widthPixels) / Page.a4.width.points
    let height = Int((Page.a4.height.points * scale).rounded())
    return try Thumbnails.rasterize(width: widthPixels, height: height) { context throws(RenderError) in
      // `draw` expects an unflipped page in points: undo the bitmap flip, then scale points to pixels.
      context.translateBy(x: 0, y: Double(height))
      context.scaleBy(x: scale, y: -scale)
      try draw(page, in: context)
    }
  }
}
