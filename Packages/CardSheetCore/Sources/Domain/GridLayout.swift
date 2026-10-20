public enum LayoutError: Error, Equatable, Sendable {
  case slotTooLarge
  case slotTooSmall
  case negativeGutter
}

/// Where the slots of a sheet land on the A4 page: as many as fit inside the safety margin, centered.
public struct GridLayout: Hashable, Sendable {
  public static let minimumSlotSide = Millimeters(tenths: 100)

  public let columns: Int
  public let rows: Int
  /// Row by row, top to bottom.
  public let slots: [MMRect]

  public var capacity: Int { columns * rows }

  public static func make(_ geometry: SheetGeometry) throws(LayoutError) -> GridLayout {
    let slot = geometry.slot
    let gutter = geometry.gutter.tenths
    guard gutter >= 0 else { throw .negativeGutter }
    guard slot.width >= minimumSlotSide, slot.height >= minimumSlotSide else { throw .slotTooSmall }

    let margin = Page.safetyMargin.tenths
    let usableWidth = Page.a4.width.tenths - 2 * margin
    let usableHeight = Page.a4.height.tenths - 2 * margin
    let columns = (usableWidth + gutter) / (slot.width.tenths + gutter)
    let rows = (usableHeight + gutter) / (slot.height.tenths + gutter)
    guard columns >= 1, rows >= 1 else { throw .slotTooLarge }

    let gridWidth = columns * slot.width.tenths + (columns - 1) * gutter
    let gridHeight = rows * slot.height.tenths + (rows - 1) * gutter
    let originX = Double(Page.a4.width.tenths - gridWidth) / 20
    let originY = Double(Page.a4.height.tenths - gridHeight) / 20
    let stepX = slot.width.mm + geometry.gutter.mm
    let stepY = slot.height.mm + geometry.gutter.mm

    let slots = (0..<rows).flatMap { row in
      (0..<columns).map { column in
        MMRect(
          x: originX + Double(column) * stepX, y: originY + Double(row) * stepY,
          width: slot.width.mm, height: slot.height.mm)
      }
    }
    return GridLayout(columns: columns, rows: rows, slots: slots)
  }
}
