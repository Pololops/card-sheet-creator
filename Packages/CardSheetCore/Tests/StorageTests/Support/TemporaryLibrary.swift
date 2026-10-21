import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A throwaway library folder plus a place to create the files a user would pick.
struct TemporaryLibrary {
  let root: URL
  let picked: URL

  init() throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    root = base.appendingPathComponent("Library")
    picked = base.appendingPathComponent("Picked")
    try FileManager.default.createDirectory(at: picked, withIntermediateDirectories: true)
  }

  func files(in folder: String) throws -> [String] {
    let url = root.appendingPathComponent(folder)
    guard FileManager.default.fileExists(atPath: url.path) else { return [] }
    return try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
  }

  func pickedPNG(named name: String, gray: CGFloat = 0.5) throws -> URL {
    try pickedImage(named: name, type: .png, gray: gray)
  }

  func pickedImage(named name: String, type: UTType, gray: CGFloat = 0.5) throws -> URL {
    guard
      let context = CGContext(
        data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw TestFileError.cannotCreate }
    context.setFillColor(CGColor(gray: gray, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
    let url = picked.appendingPathComponent(name)
    guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL, type.identifier as CFString, 1, nil)
    else { throw TestFileError.cannotCreate }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw TestFileError.cannotCreate }
    return url
  }

  func pickedText(named name: String) throws -> URL {
    let url = picked.appendingPathComponent(name)
    try Data("not an image".utf8).write(to: url)
    return url
  }
}

enum TestFileError: Error {
  case cannotCreate
}
