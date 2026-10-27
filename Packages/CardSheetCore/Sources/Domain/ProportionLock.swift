public enum SlotSide: Sendable {
  case width, height

  public var keyPath: WritableKeyPath<SlotSize, Millimeters> { self == .width ? \.width : \.height }
  var other: SlotSide { self == .width ? .height : .width }
}

/// Keeps a slot's proportions while one side is edited. The other side follows the reference captured
/// when the lock took over, never the previous rounded values, so repeated steps cannot drift.
public struct ProportionLock: Sendable {
  private var reference: SlotSize?
  /// What the lock last produced: any other current slot was changed elsewhere and becomes the reference.
  private var produced: SlotSize?

  public init() {}

  /// `nil` when no value keeps both sides in bounds; geometry is read from disk and may be degenerate.
  public func range(of side: SlotSide, for current: SlotSize, minimum: Millimeters, maximum: SlotSize)
    -> ClosedRange<Millimeters>?
  {
    let kept = reference(for: current)
    let edited = kept[keyPath: side.keyPath].tenths
    let followed = kept[keyPath: side.other.keyPath].tenths
    guard edited > 0, followed > 0 else { return nil }
    let lower = max(minimum.tenths, Self.scale(minimum.tenths, edited, followed, .up))
    let upper = min(
      maximum[keyPath: side.keyPath].tenths,
      Self.scale(maximum[keyPath: side.other.keyPath].tenths, edited, followed, .down))
    guard lower <= upper else { return nil }
    return Millimeters(tenths: lower)...Millimeters(tenths: upper)
  }

  public func resized(_ current: SlotSize, setting side: SlotSide, to value: Millimeters) -> SlotSize {
    let kept = reference(for: current)
    var slot = current
    slot[keyPath: side.keyPath] = value
    let edited = kept[keyPath: side.keyPath].tenths
    guard edited > 0 else { return slot }
    slot[keyPath: side.other.keyPath] = Millimeters(
      tenths: Self.scale(
        value.tenths, kept[keyPath: side.other.keyPath].tenths, edited, .toNearestOrAwayFromZero))
    return slot
  }

  /// Call only once `produced` was actually applied, so a refused edit cannot move the reference.
  public mutating func record(_ produced: SlotSize, from current: SlotSize) {
    reference = reference(for: current)
    self.produced = produced
  }

  private func reference(for current: SlotSize) -> SlotSize {
    guard let reference, produced == current else { return current }
    return reference
  }

  private static func scale(
    _ value: Int, _ numerator: Int, _ denominator: Int, _ rule: FloatingPointRoundingRule
  ) -> Int {
    Int((Double(value * numerator) / Double(denominator)).rounded(rule))
  }
}
