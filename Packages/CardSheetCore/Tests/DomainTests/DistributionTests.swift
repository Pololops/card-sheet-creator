import Foundation
import Testing

@testable import Domain

@Suite struct DistributionTests {
  private let template = Template.standardDefault(id: UUID(), now: .distantPast)

  private func images(_ count: Int) -> [ImageRef] {
    (0..<count).map { ImageRef(sha256: "hash\($0)", fileExtension: "png") }
  }

  private func distribute(_ images: [ImageRef], baseName: String = "Contes") throws -> [Sheet] {
    try Distribution.sheets(
      for: images, from: template, baseName: baseName, now: .distantPast, makeID: UUID.init)
  }

  @Test func singleImageIsDuplicatedOnEverySlotOfOneSheet() throws {
    let image = ImageRef(sha256: "moon", fileExtension: "png")

    let sheets = try distribute([image], baseName: "Lune")

    #expect(sheets.count == 1)
    #expect(sheets[0].fillMode == .duplicated)
    #expect(try sheets[0].slotContents() == Array(repeating: image, count: 9))
    #expect(sheets[0].name == "Lune")
  }

  @Test func tenImagesOnNineSlotsMakeTwoSheets() throws {
    let sheets = try distribute(images(10))

    #expect(sheets.count == 2)
    #expect(sheets.map(\.images.count) == [9, 1])
    #expect(sheets.map(\.name) == ["Contes 1/2", "Contes 2/2"])
  }

  @Test func selectionOrderIsPreserved() throws {
    let selection = images(12)

    let sheets = try distribute(selection)

    #expect(sheets.flatMap(\.images) == selection)
  }

  @Test func lastSheetLeavesRemainingSlotsEmpty() throws {
    let sheets = try distribute(images(11))

    let contents = try sheets[1].slotContents()
    #expect(contents.compactMap { $0 }.count == 2)
    #expect(contents.count == 9)
  }

  @Test func sheetsKeepTheTemplateGeometryAndOrigin() throws {
    let sheets = try distribute(images(3))

    #expect(sheets[0].geometry == template.geometry)
    #expect(sheets[0].sourceTemplateID == template.id)
  }

  @Test func noImageCreatesNoSheet() throws {
    #expect(try distribute([]).isEmpty)
  }
}
