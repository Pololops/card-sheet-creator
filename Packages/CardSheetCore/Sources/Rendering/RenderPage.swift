import Domain

/// What one printed page needs: the grid geometry and the image of each slot.
public struct RenderPage: Sendable {
  public var geometry: SheetGeometry
  /// One entry per slot, row by row; `nil` leaves the slot blank.
  public var contents: [ImageRef?]
  public var crops: [String: CropAnchor]

  public init(geometry: SheetGeometry, contents: [ImageRef?], crops: [String: CropAnchor] = [:]) {
    self.geometry = geometry
    self.contents = contents
    self.crops = crops
  }

  public init(sheet: Sheet) throws(LayoutError) {
    self.init(geometry: sheet.geometry, contents: try sheet.slotContents(), crops: sheet.crops)
  }
}

public enum RenderError: Error, Equatable, Sendable {
  case unreadableImage(ImageRef)
  case cannotCreateDocument
  case invalidLayout(LayoutError)
}
