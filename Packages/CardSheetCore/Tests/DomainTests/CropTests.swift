import Foundation
import Testing

@testable import Domain

@Suite struct CropTests {
  private let slot = SlotSize.standardCard
  private let landscape = PixelSize(width: 3000, height: 2000)

  @Test func coverRectCoversTheWholeSlot() {
    let rect = Crop.coverRect(image: landscape, slot: slot, anchor: .centered)

    #expect(rect.x <= 0 && rect.maxX >= 54)
    #expect(rect.y <= 0 && rect.maxY >= 85.6)
  }

  @Test func centeredAnchorSplitsTheOverflowEvenly() {
    let rect = Crop.coverRect(image: landscape, slot: slot, anchor: .centered)

    #expect(abs(rect.height - 85.6) < 0.0001)
    #expect(abs(rect.x + (rect.width - 54) / 2) < 0.0001)
  }

  @Test func anchorZeroAlignsTheImageLeftEdgeWithTheSlot() {
    let rect = Crop.coverRect(image: landscape, slot: slot, anchor: CropAnchor(x: 0, y: 0.5))

    #expect(rect.x == 0)
  }

  @Test func dragIsClampedToTheImageEdges() {
    let farRight = Crop.anchor(
      .centered, afterDragBy: MMOffset(dx: 1000, dy: 0), image: landscape, slot: slot)
    let farLeft = Crop.anchor(
      .centered, afterDragBy: MMOffset(dx: -1000, dy: 0), image: landscape, slot: slot)

    #expect(farRight.x == 0)
    #expect(farLeft.x == 1)
  }

  @Test func imageWithTheSlotRatioCannotMove() {
    let sameRatio = PixelSize(width: 540, height: 856)

    let anchor = Crop.anchor(.centered, afterDragBy: MMOffset(dx: 20, dy: 20), image: sameRatio, slot: slot)

    #expect(anchor == .centered)
  }

  @Test func imageWithTheSlotRatioCannotBeReframed() {
    let sameRatio = PixelSize(width: 540, height: 856)

    #expect(!Crop.canReframe(image: sameRatio, slot: slot))
  }

  @Test func overflowingImageCanBeReframed() {
    #expect(Crop.canReframe(image: landscape, slot: slot))
  }

  @Test func dragOnlyMovesTheOverflowingAxis() {
    let anchor = Crop.anchor(.centered, afterDragBy: MMOffset(dx: 0, dy: 30), image: landscape, slot: slot)

    #expect(anchor.y == 0.5)
  }

  @Test func dragNearTheCenterSnapsToIt() {
    let start = CropAnchor(x: 0.3, y: 0.5)
    let overflow = Crop.coverRect(image: landscape, slot: slot, anchor: start).width - 54
    let toCenter = (0.5 - 0.3) * overflow

    let anchor = Crop.anchor(
      start, afterDragBy: MMOffset(dx: -(toCenter - 0.8), dy: 0), image: landscape, slot: slot)

    #expect(anchor == .centered)
    #expect(Crop.isCentered(anchor))
  }

  @Test func dragFurtherThanOneMillimetreFromCenterDoesNotSnap() {
    let anchor = Crop.anchor(.centered, afterDragBy: MMOffset(dx: 1.5, dy: 0), image: landscape, slot: slot)

    #expect(anchor != .centered)
    #expect(!Crop.isCentered(anchor))
  }

  @Test func portraitImageMovesVertically() {
    let portrait = PixelSize(width: 1000, height: 3000)

    let anchor = Crop.anchor(.centered, afterDragBy: MMOffset(dx: 0, dy: 10), image: portrait, slot: slot)

    #expect(anchor.y < 0.5)
    #expect(anchor.x == 0.5)
  }
}
