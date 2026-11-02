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

  // MARK: - Pan target

  private static let panScale = 2.0
  private static let firstImage = ImageRef(sha256: "first", fileExtension: "png")
  private static let secondImage = ImageRef(sha256: "second", fileExtension: "png")
  private let panLayout = try? GridLayout.make(SheetGeometry(slot: .standardCard))

  private func center(ofSlot index: Int) throws -> CGPoint {
    let frame = try #require(panLayout?.slots[index]).scaled(Self.panScale)
    return CGPoint(x: frame.midX, y: frame.midY)
  }

  @Test func panTargetIsTheSelectedSlotUnderThePointer() throws {
    let target = SheetCanvas.panTarget(
      at: try center(ofSlot: 1), layout: panLayout, contents: [Self.firstImage, Self.secondImage],
      selectedSlot: 1, scale: Self.panScale)

    #expect(target?.slot == 1)
    #expect(target?.image == Self.secondImage)
  }

  @Test func panTargetIgnoresAnUnselectedSlot() throws {
    let target = SheetCanvas.panTarget(
      at: try center(ofSlot: 0), layout: panLayout, contents: [Self.firstImage, Self.secondImage],
      selectedSlot: 1, scale: Self.panScale)

    #expect(target == nil)
  }

  @Test func panTargetIgnoresAnEmptySlot() throws {
    let target = SheetCanvas.panTarget(
      at: try center(ofSlot: 1), layout: panLayout, contents: [Self.firstImage, nil], selectedSlot: 1,
      scale: Self.panScale)

    #expect(target == nil)
  }

  @Test func panTargetIgnoresAPointBetweenSlots() throws {
    let first = try #require(panLayout?.slots[0]).scaled(Self.panScale)
    let gutter = CGPoint(
      x: first.maxX + SheetGeometry.defaultGutter.mm * Self.panScale / 2, y: first.midY)

    let target = SheetCanvas.panTarget(
      at: gutter, layout: panLayout, contents: [Self.firstImage, Self.secondImage], selectedSlot: 0,
      scale: Self.panScale)

    #expect(target == nil)
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
