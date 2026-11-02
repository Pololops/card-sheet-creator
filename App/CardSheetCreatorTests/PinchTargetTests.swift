import CoreGraphics
import Domain
import Testing

@testable import CardSheetCreator

@Suite struct PinchTargetTests {
  private static let scale = 2.0
  private let layout = try? GridLayout.make(SheetGeometry(slot: .standardCard))

  private func points(fromMillimetres x: Double, _ y: Double) -> CGPoint {
    CGPoint(x: x * Self.scale, y: y * Self.scale)
  }

  @Test func aPinchStartingOnASlotResizesTheSlots() throws {
    let slot = try #require(layout?.slots.first).scaled(Self.scale)

    let target = PinchTarget.at(CGPoint(x: slot.midX, y: slot.midY), layout: layout, scale: Self.scale)

    #expect(target == .slots)
  }

  @Test func aPinchStartingInTheGutterZoomsTheView() throws {
    let slot = try #require(layout?.slots.first)
    let gutter = points(
      fromMillimetres: slot.maxX + SheetGeometry.defaultGutter.mm / 2, slot.y + slot.height / 2)

    let target = PinchTarget.at(gutter, layout: layout, scale: Self.scale)

    #expect(target == .view)
  }

  @Test func aPinchStartingInTheSafetyMarginZoomsTheView() {
    let margin = points(fromMillimetres: Page.safetyMargin.mm / 2, Page.safetyMargin.mm / 2)

    let target = PinchTarget.at(margin, layout: layout, scale: Self.scale)

    #expect(target == .view)
  }

  @Test func aPinchStartingOffThePageZoomsTheView() {
    let target = PinchTarget.at(CGPoint(x: -40, y: -40), layout: layout, scale: Self.scale)

    #expect(target == .view)
  }

  @Test func aPinchWithoutATemplateZoomsTheView() throws {
    let slot = try #require(layout?.slots.first).scaled(Self.scale)

    let target = PinchTarget.at(CGPoint(x: slot.midX, y: slot.midY), layout: nil, scale: Self.scale)

    #expect(target == .view)
  }
}
