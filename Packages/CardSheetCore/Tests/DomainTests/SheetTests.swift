import Foundation
import Testing

@testable import Domain

@Suite struct SheetTests {
  private let moon = ImageRef(sha256: "moon", fileExtension: "png")
  private let fox = ImageRef(sha256: "fox", fileExtension: "jpg")

  private func listSheet(_ images: [ImageRef], name: String = "Contes") -> Sheet {
    Sheet(
      id: UUID(), name: name, geometry: SheetGeometry(slot: .standardCard, gutter: .init(tenths: 20)),
      sourceTemplateID: nil, fillMode: .list, images: images, createdAt: .distantPast, updatedAt: .distantPast
    )
  }

  private func images(_ count: Int) -> [ImageRef] {
    (0..<count).map { ImageRef(sha256: "hash\($0)", fileExtension: "png") }
  }

  private func resize(_ sheet: Sheet, width: Int, height: Int) throws -> ResizeOutcome {
    let geometry = SheetGeometry(
      slot: SlotSize(width: .init(tenths: width), height: .init(tenths: height)), gutter: .init(tenths: 20))
    return try sheet.resized(to: geometry, now: .distantFuture, makeID: UUID.init)
  }

  @Test func croppingAnImageAppliesToEveryClone() {
    var sheet = listSheet([moon, fox, moon])
    let anchor = CropAnchor(x: 0.2, y: 0.5)

    sheet.setCrop(anchor, for: moon)

    #expect(sheet.crop(for: moon) == anchor)
    #expect(sheet.crop(for: fox) == .centered)
  }

  @Test func clonesAreTheSlotsSharingTheSameImage() {
    let sheet = listSheet([moon, fox, moon])

    #expect(sheet.cloneCount(of: moon) == 2)
    #expect(sheet.cloneCount(of: fox) == 1)
  }

  @Test func duplicatedSheetCountsEverySlotAsAClone() throws {
    var sheet = listSheet([moon])
    sheet.fillMode = .duplicated

    #expect(try sheet.slotContents().count == 9)
    #expect(sheet.cloneCount(of: moon) == 9)
  }

  @Test func shrinkingMovesOverflowImagesToANewSheet() throws {
    let outcome = try resize(listSheet(images(9)), width: 660, height: 900)

    #expect(outcome.sheet.images == Array(images(9).prefix(6)))
    #expect(outcome.overflow.count == 1)
    #expect(outcome.overflow[0].images == Array(images(9).suffix(3)))
    #expect(outcome.overflow[0].name == "Contes (suite)")
    #expect(outcome.movedCount == 3)
  }

  @Test func largeShrinkCreatesSeveralOverflowSheets() throws {
    let outcome = try resize(listSheet(images(9)), width: 1000, height: 1400)

    #expect(outcome.sheet.images.count == 2)
    #expect(outcome.overflow.map(\.images.count) == [2, 2, 2, 1])
    #expect(
      outcome.overflow.map(\.name) == [
        "Contes (suite)", "Contes (suite 2)", "Contes (suite 3)", "Contes (suite 4)",
      ])
  }

  @Test func growingKeepsEveryImageAndLeavesEmptySlots() throws {
    let outcome = try resize(listSheet(images(4)), width: 500, height: 700)

    #expect(outcome.sheet.images == images(4))
    #expect(outcome.overflow.isEmpty)
    #expect(try outcome.sheet.slotContents().count == 12)
  }

  @Test func duplicatedSheetStaysDuplicatedOnResize() throws {
    var sheet = listSheet([moon])
    sheet.fillMode = .duplicated

    let outcome = try resize(sheet, width: 1000, height: 1400)

    #expect(outcome.overflow.isEmpty)
    #expect(try outcome.sheet.slotContents() == [moon, moon])
  }

  @Test func cropsFollowTheirImagesAfterResize() throws {
    var sheet = listSheet(images(9))
    let anchor = CropAnchor(x: 0.1, y: 0.5)
    sheet.setCrop(anchor, for: images(9)[8])
    sheet.setCrop(anchor, for: images(9)[0])

    let outcome = try resize(sheet, width: 660, height: 900)

    #expect(outcome.sheet.crop(for: images(9)[0]) == anchor)
    #expect(outcome.overflow[0].crop(for: images(9)[8]) == anchor)
  }

  @Test func resizeKeepsTheSheetIdentityAndTouchesItsDate() throws {
    let sheet = listSheet(images(3))

    let outcome = try resize(sheet, width: 600, height: 900)

    #expect(outcome.sheet.id == sheet.id)
    #expect(outcome.sheet.updatedAt == .distantFuture)
  }

  @Test func resizeToAnImpossibleSizeThrows() {
    #expect(throws: LayoutError.slotTooLarge) { try resize(listSheet(images(3)), width: 2500, height: 900) }
  }
}
