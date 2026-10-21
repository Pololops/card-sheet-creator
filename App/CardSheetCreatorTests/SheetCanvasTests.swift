import AppKit
import Domain
import Foundation
import Storage
import SwiftUI
import Testing

@testable import CardSheetCreator

@MainActor @Suite struct SheetCanvasTests {
  private static let renderTimeout: Duration = .seconds(3)
  private static let pollInterval: Duration = .milliseconds(50)
  /// A cancelled load finishes late: the slot must stay paper long enough for such a write to land.
  private static let settleWindow: Duration = .milliseconds(300)
  /// The 50% gray test image renders around 0.64 once color-managed; the placeholder and the paper are near 0.9 and 1.
  private static let imageMaxBrightness = 0.75
  private static let paperMinBrightness = 0.95

  /// Switching sheets reuses the slot views, so a slot left empty must not keep the previous sheet's pixels.
  @Test func emptySlotDoesNotKeepThePreviousSheetsImage() async throws {
    let (store, _, sheet) = try await TestLibrary.sheetWithOneImage()
    var full = sheet
    full.fillMode = .duplicated
    var partial = full
    partial.fillMode = .list
    let lastSlot = try #require(GridLayout.make(full.geometry).slots.last).scaled(1)
    let probe = CGPoint(x: lastSlot.midX, y: lastSlot.midY)
    let images = ImageCache(persistence: store)
    let host = NSHostingView(rootView: canvas(full, images: images))
    // The thresholds assume the light placeholder, whatever the system appearance.
    host.appearance = NSAppearance(named: .aqua)
    let window = NSWindow(
      contentRect: CGRect(origin: .zero, size: host.fittingSize), styleMask: .borderless, backing: .buffered,
      defer: false)
    window.contentView = host
    try #require(await waitUntil { brightness(of: host, at: probe) < Self.imageMaxBrightness })

    host.rootView = canvas(partial, images: images)

    let isPaper = { brightness(of: host, at: probe) > Self.paperMinBrightness }
    #expect(await waitUntil(isPaper))
    #expect(await holdsTrue(for: Self.settleWindow, isPaper))
  }

  private func canvas(_ sheet: Sheet, images: ImageCache) -> SheetCanvas {
    SheetCanvas(
      sheet: sheet, geometry: sheet.geometry, scale: 1, images: images, isEditable: false,
      selectedSlot: .constant(nil), onCropChange: { _, _ in })
  }

  /// Darkest RGB component of the rendered pixel, so any tint counts as darker than the white paper.
  private func brightness(of view: NSView, at point: CGPoint) -> Double {
    view.layoutSubtreeIfNeeded()
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return .nan }
    view.cacheDisplay(in: view.bounds, to: rep)
    let pixelsPerPoint = CGFloat(rep.pixelsWide) / view.bounds.width
    let color = rep.colorAt(x: Int(point.x * pixelsPerPoint), y: Int(point.y * pixelsPerPoint))
    guard let rgb = color?.usingColorSpace(.deviceRGB) else { return .nan }
    return min(rgb.redComponent, rgb.greenComponent, rgb.blueComponent)
  }

  private func waitUntil(_ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + Self.renderTimeout
    while ContinuousClock.now < deadline {
      if condition() { return true }
      try? await Task.sleep(for: Self.pollInterval)
    }
    return condition()
  }

  private func holdsTrue(for window: Duration, _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + window
    while ContinuousClock.now < deadline {
      guard condition() else { return false }
      try? await Task.sleep(for: Self.pollInterval)
    }
    return condition()
  }
}
