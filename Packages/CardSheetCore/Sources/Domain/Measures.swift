/// A length stored in whole tenths of a millimetre, so layout arithmetic stays exact.
public struct Millimeters: Hashable, Comparable, Sendable, Codable {
  public static let zero = Millimeters(tenths: 0)
  private static let pointsPerInch = 72.0
  private static let millimetresPerInch = 25.4

  public var tenths: Int

  public init(tenths: Int) {
    self.tenths = tenths
  }

  public init(mm: Double) {
    tenths = Int((mm * 10).rounded())
  }

  public var mm: Double { Double(tenths) / 10 }
  public var points: Double { mm * Self.pointsPerInch / Self.millimetresPerInch }

  public static func < (lhs: Millimeters, rhs: Millimeters) -> Bool { lhs.tenths < rhs.tenths }

  public init(from decoder: Decoder) throws {
    tenths = try decoder.singleValueContainer().decode(Int.self)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(tenths)
  }
}

public struct SlotSize: Hashable, Sendable, Codable {
  /// ID-1 card format (credit-card size).
  public static let standardCard = SlotSize(width: Millimeters(tenths: 540), height: Millimeters(tenths: 856))

  public var width: Millimeters
  public var height: Millimeters

  public init(width: Millimeters, height: Millimeters) {
    self.width = width
    self.height = height
  }
}

public struct SheetGeometry: Hashable, Sendable, Codable {
  public static let defaultGutter = Millimeters(tenths: 20)

  public var slot: SlotSize
  public var gutter: Millimeters

  public init(slot: SlotSize, gutter: Millimeters = SheetGeometry.defaultGutter) {
    self.slot = slot
    self.gutter = gutter
  }
}

public enum Page {
  public static let a4 = SlotSize(width: Millimeters(tenths: 2100), height: Millimeters(tenths: 2970))
  /// Kept free on every edge so no printer's unprintable area can clip a card.
  public static let safetyMargin = Millimeters(tenths: 50)

  /// The page inside the safety margin: the largest area a slot may occupy.
  public static var usableArea: SlotSize {
    let margin = 2 * safetyMargin.tenths
    return SlotSize(
      width: Millimeters(tenths: a4.width.tenths - margin),
      height: Millimeters(tenths: a4.height.tenths - margin))
  }
}

/// A rectangle in millimetres, origin at the top-left corner of the page or slot.
public struct MMRect: Hashable, Sendable {
  public var x: Double
  public var y: Double
  public var width: Double
  public var height: Double

  public init(x: Double, y: Double, width: Double, height: Double) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }

  public var maxX: Double { x + width }
  public var maxY: Double { y + height }
}

public struct MMOffset: Hashable, Sendable {
  public var dx: Double
  public var dy: Double

  public init(dx: Double, dy: Double) {
    self.dx = dx
    self.dy = dy
  }
}

public struct PixelSize: Hashable, Sendable, Codable {
  public var width: Int
  public var height: Int

  public init(width: Int, height: Int) {
    self.width = width
    self.height = height
  }
}
