import Foundation
import Testing

@testable import CardSheetCreator

@MainActor @Suite struct ImageCacheTests {
  /// A drag reads the size on every pointer move, so it must not wait once the slot has drawn its image.
  @Test func sizeIsKnownWithoutWaitingOnceLoaded() async throws {
    let (store, _, sheet) = try await TestLibrary.sheetWithOneImage()
    let image = try #require(sheet.images.first)
    let cache = ImageCache(persistence: store)
    let loaded = try #require(await cache.displaySize(of: image))

    let cached = cache.cachedDisplaySize(of: image)

    #expect(cached == loaded)
  }

  /// Until the slot has loaded its image, a drag has no size to work with and is ignored.
  @Test func sizeIsUnknownBeforeAnyLoad() async throws {
    let (store, _, sheet) = try await TestLibrary.sheetWithOneImage()
    let image = try #require(sheet.images.first)

    let cached = ImageCache(persistence: store).cachedDisplaySize(of: image)

    #expect(cached == nil)
  }
}
