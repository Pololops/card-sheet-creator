import Testing

@testable import Domain

@Suite struct GridLayoutTests {
  private let standard = SheetGeometry(slot: .standardCard, gutter: .init(tenths: 20))

  @Test func standardCardWithDefaultGutterPacksThreeByThree() throws {
    let layout = try GridLayout.make(standard)

    #expect(layout.columns == 3)
    #expect(layout.rows == 3)
    #expect(layout.capacity == 9)
  }

  @Test func gridIsCenteredOnA4() throws {
    let layout = try GridLayout.make(standard)

    let first = try #require(layout.slots.first)
    let last = try #require(layout.slots.last)
    #expect(abs(first.x - 22) < 0.001)
    #expect(abs(first.y - 18.1) < 0.001)
    #expect(abs((210 - last.maxX) - first.x) < 0.001)
    #expect(abs((297 - last.maxY) - first.y) < 0.001)
  }

  @Test func slotsAreOrderedRowByRow() throws {
    let layout = try GridLayout.make(standard)

    #expect(layout.slots[1].y == layout.slots[0].y)
    #expect(layout.slots[1].x > layout.slots[0].x)
    #expect(layout.slots[3].y > layout.slots[0].y)
  }

  @Test func zeroGutterPacksMoreSlotsThanTwoMillimetres() throws {
    let slot = SlotSize(width: .init(tenths: 500), height: .init(tenths: 700))

    let tight = try GridLayout.make(SheetGeometry(slot: slot, gutter: .zero))
    let spaced = try GridLayout.make(SheetGeometry(slot: slot, gutter: .init(tenths: 20)))

    #expect(tight.columns == 4)
    #expect(spaced.columns == 3)
  }

  @Test func slotWiderThanUsableAreaIsRejected() {
    let geometry = SheetGeometry(
      slot: SlotSize(width: .init(tenths: 2005), height: .init(tenths: 856)), gutter: .zero)

    #expect(throws: LayoutError.slotTooLarge) { try GridLayout.make(geometry) }
  }

  @Test func slotSmallerThanMinimumIsRejected() {
    let geometry = SheetGeometry(
      slot: SlotSize(width: .init(tenths: 95), height: .init(tenths: 856)), gutter: .zero)

    #expect(throws: LayoutError.slotTooSmall) { try GridLayout.make(geometry) }
  }

  @Test func negativeGutterIsRejected() {
    let geometry = SheetGeometry(slot: .standardCard, gutter: .init(tenths: -10))

    #expect(throws: LayoutError.negativeGutter) { try GridLayout.make(geometry) }
  }

  @Test func slotFillingTheWholeUsableAreaFitsOnce() throws {
    let geometry = SheetGeometry(
      slot: SlotSize(width: .init(tenths: 2000), height: .init(tenths: 2870)), gutter: .zero)

    let layout = try GridLayout.make(geometry)

    #expect(layout.capacity == 1)
    #expect(layout.slots == [MMRect(x: 5, y: 5, width: 200, height: 287)])
  }

  @Test(arguments: [(540, 856, 20), (300, 500, 0), (450, 740, 20), (1000, 1400, 50), (660, 900, 20)])
  func everySlotStaysInsideTheSafetyMargin(width: Int, height: Int, gutter: Int) throws {
    let geometry = SheetGeometry(
      slot: SlotSize(width: .init(tenths: width), height: .init(tenths: height)),
      gutter: .init(tenths: gutter))

    let layout = try GridLayout.make(geometry)

    for slot in layout.slots {
      #expect(slot.x >= 5 && slot.maxX <= 205)
      #expect(slot.y >= 5 && slot.maxY <= 292)
    }
  }
}
