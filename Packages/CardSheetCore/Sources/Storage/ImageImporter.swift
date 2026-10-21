import CoreGraphics
import CryptoKit
import Domain
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Copies picked files into the library, keyed by content hash, after checking they decode.
struct ImageImporter {
  let directory: URL

  func importImages(at urls: [URL]) -> ImportReport {
    var report = ImportReport(imported: [], skipped: [])
    for url in urls {
      do {
        report.imported.append(try importImage(at: url))
      } catch {
        report.skipped.append(SkippedFile(fileName: url.lastPathComponent, reason: error))
      }
    }
    return report
  }

  private func importImage(at url: URL) throws(SkipReason) -> ImageRef {
    let fileExtension = url.pathExtension.lowercased()
    guard let type = UTType(filenameExtension: fileExtension),
      UTType.cardImages.contains(where: { type.conforms(to: $0) })
    else { throw .unsupportedFormat }

    let isScoped = url.startAccessingSecurityScopedResource()
    defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
    guard let data = try? Data(contentsOf: url), Self.decodes(data, asPDF: type.conforms(to: .pdf)) else {
      throw .unreadable
    }

    let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    let image = ImageRef(sha256: hash, fileExtension: fileExtension, originalName: url.lastPathComponent)
    let destination = directory.appendingPathComponent(image.fileName)
    if !FileManager.default.fileExists(atPath: destination.path) {
      do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: destination, options: .atomic)
      } catch {
        throw .unreadable
      }
    }
    return image
  }

  private static func decodes(_ data: Data, asPDF: Bool) -> Bool {
    if asPDF {
      guard let provider = CGDataProvider(data: data as CFData) else { return false }
      return CGPDFDocument(provider)?.page(at: 1) != nil
    }
    guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0,
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    else { return false }
    return properties[kCGImagePropertyPixelWidth] != nil
  }
}

extension SkipReason: Error {}

extension UTType {
  /// Image formats a sheet accepts: what ImageIO decodes, plus the first page of a PDF.
  public static let cardImages: [UTType] = [
    .png, .jpeg, .heic, .heif, .tiff, .webP, .gif, .bmp, UTType(importedAs: "public.avif"), .pdf,
  ]
}
