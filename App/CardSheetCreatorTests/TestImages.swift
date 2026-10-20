import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum TestImages {
  /// Writes a small solid PNG; different `gray` values give different contents, hence different hashes.
  static func png(at url: URL, gray: Double) throws -> URL {
    guard
      let context = CGContext(
        data: nil, width: 30, height: 20, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw TestImageError.cannotCreate }
    context.setFillColor(CGColor(gray: gray, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 30, height: 20))
    guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw TestImageError.cannotCreate }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw TestImageError.cannotCreate }
    return url
  }
}

enum TestImageError: Error {
  case cannotCreate
}
