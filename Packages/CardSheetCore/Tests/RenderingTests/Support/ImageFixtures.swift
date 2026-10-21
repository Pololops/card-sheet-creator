import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Writes small test images to a temporary folder, so no binary fixture lives in the repo.
struct ImageFixtures {
  let directory: URL

  init() throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  /// Left half `left`, right half `right` (equal colours give a solid image).
  func bitmap(
    named name: String, width: Int, height: Int, left: CGColor, right: CGColor,
    type: UTType = .png, orientation: Int = 1, colorSpace: CGColorSpace = Palette.sRGB
  ) throws -> URL {
    let context = try requireContext(width: width, height: height, colorSpace: colorSpace)
    context.setFillColor(left)
    context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
    context.setFillColor(right)
    context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
    guard let image = context.makeImage() else { throw FixtureError.cannotDraw }

    let url = directory.appendingPathComponent(name)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)
    else { throw FixtureError.cannotDraw }
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw FixtureError.cannotDraw }
    return url
  }

  /// A PDF whose pages are filled with the given colours, in order.
  func pdf(named name: String, pageColors: [CGColor]) throws -> URL {
    let url = directory.appendingPathComponent(name)
    var box = CGRect(x: 0, y: 0, width: 200, height: 300)
    guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { throw FixtureError.cannotDraw }
    for color in pageColors {
      context.beginPDFPage(nil)
      context.setFillColor(color)
      context.fill(box)
      context.endPDFPage()
    }
    context.closePDF()
    return url
  }

  /// In-memory bitmap of square stripes side by side, one per colour, in the given colour space.
  func stripes(of colors: [CGColor], size: Int, colorSpace: CGColorSpace = Palette.sRGB) throws -> CGImage {
    let context = try requireContext(width: size * colors.count, height: size, colorSpace: colorSpace)
    for (index, color) in colors.enumerated() {
      context.setFillColor(color)
      context.fill(CGRect(x: index * size, y: 0, width: size, height: size))
    }
    guard let image = context.makeImage() else { throw FixtureError.cannotDraw }
    return image
  }

  private func requireContext(width: Int, height: Int, colorSpace: CGColorSpace) throws -> CGContext {
    guard
      let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw FixtureError.cannotDraw }
    return context
  }
}

enum FixtureError: Error {
  case cannotDraw
}

enum Palette {
  static let sRGB = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
  static let displayP3 = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
  static let red = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
  static let blue = CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
  static let green = CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)
}
