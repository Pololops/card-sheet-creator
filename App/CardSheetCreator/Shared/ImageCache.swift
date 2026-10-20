import CoreGraphics
import Domain
import Foundation
import Rendering
import Storage

/// Decoded images for the screen, loaded off the main thread and kept while memory allows.
@MainActor
final class ImageCache {
  private let persistence: any LibraryPersistence
  private let images = NSCache<NSString, CGImage>()
  private var sizes: [String: PixelSize] = [:]

  init(persistence: any LibraryPersistence) {
    self.persistence = persistence
  }

  func url(for image: ImageRef) -> URL {
    persistence.imageURL(for: image)
  }

  func displaySize(of image: ImageRef) async -> PixelSize? {
    if let size = sizes[image.sha256] { return size }
    let url = url(for: image)
    let size = await Self.loadSize(image, url: url)
    sizes[image.sha256] = size
    return size
  }

  func thumbnail(of image: ImageRef, maxPixelSize: Int) async -> CGImage? {
    let key = "\(image.sha256)-\(maxPixelSize)" as NSString
    if let cached = images.object(forKey: key) { return cached }
    let loaded = await Self.loadThumbnail(image, url: url(for: image), maxPixelSize: maxPixelSize)
    if let loaded { images.setObject(loaded, forKey: key) }
    return loaded
  }

  func pageThumbnail(of sheet: Sheet, widthPixels: Int) async -> CGImage? {
    let key = "page-\(sheet.id)-\(sheet.updatedAt.timeIntervalSince1970)-\(widthPixels)" as NSString
    if let cached = images.object(forKey: key) { return cached }
    let persistence = persistence
    let renderer = SheetRenderer(
      imageURL: { persistence.imageURL(for: $0) }, resolution: SheetRenderer.previewResolution)
    let loaded = await Self.renderPage(sheet, renderer: renderer, widthPixels: widthPixels)
    if let loaded { images.setObject(loaded, forKey: key) }
    return loaded
  }

  @concurrent
  private nonisolated static func loadSize(_ image: ImageRef, url: URL) async -> PixelSize? {
    try? Thumbnails.displaySize(of: image, at: url)
  }

  @concurrent
  private nonisolated static func loadThumbnail(_ image: ImageRef, url: URL, maxPixelSize: Int) async
    -> CGImage?
  {
    try? Thumbnails.image(of: image, at: url, maxPixelSize: maxPixelSize)
  }

  @concurrent
  private nonisolated static func renderPage(_ sheet: Sheet, renderer: SheetRenderer, widthPixels: Int) async
    -> CGImage?
  {
    guard let page = try? RenderPage(sheet: sheet) else { return nil }
    return try? renderer.renderImage(page, widthPixels: widthPixels)
  }
}
