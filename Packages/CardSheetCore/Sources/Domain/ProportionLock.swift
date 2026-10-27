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

  /// `nil` when the slot itself is out of bounds; geometry is read from disk and may be degenerate.
  public func range(of side: SlotSide, for current: SlotSize, minimum: Millimeters, maximum: SlotSize)
    -> ClosedRange<Millimeters>?
  {
    let (edited, followed) = Self.tenths(of: reference(for: current), editing: side)
    let editedMaximum = maximum[keyPath: side.keyPath].tenths
    let followedMaximum = maximum[keyPath: side.other.keyPath].tenths
    guard (minimum.tenths...editedMaximum).contains(edited),
      (minimum.tenths...followedMaximum).contains(followed)
    else { return nil }
    let lower = max(minimum.tenths, Self.scale(minimum.tenths, by: edited, over: followed, rounding: .up))
    let upper = min(editedMaximum, Self.scale(followedMaximum, by: edited, over: followed, rounding: .down))
    return Millimeters(tenths: lower)...Millimeters(tenths: upper)
  }

  public func resized(_ current: SlotSize, setting side: SlotSide, to value: Millimeters) -> SlotSize {
    // Fields write unchanged values back on every focus loss; deriving again would round the other side
    // away from what the user set.
    guard current[keyPath: side.keyPath] != value else { return current }
    let (edited, followed) = Self.tenths(of: reference(for: current), editing: side)
    var slot = current
    slot[keyPath: side.keyPath] = value
    guard edited > 0 else { return slot }
    slot[keyPath: side.other.keyPath] = Millimeters(
      tenths: Self.scale(value.tenths, by: followed, over: edited, rounding: .toNearestOrAwayFromZero))
    return slot
  }

  /// Keeps the result as the lock's own only once `apply` accepted it, so a refused edit cannot move the
  /// reference.
  public mutating func resize(
    _ current: SlotSize, setting side: SlotSide, to value: Millimeters, apply: (SlotSize) -> Bool
  ) {
    let next = resized(current, setting: side, to: value)
    guard apply(next) else { return }
    reference = reference(for: current)
    produced = next
  }

  private func reference(for current: SlotSize) -> SlotSize {
    guard let reference, produced == current else { return current }
    return reference
  }

  private static func tenths(of slot: SlotSize, editing side: SlotSide) -> (edited: Int, followed: Int) {
    (slot[keyPath: side.keyPath].tenths, slot[keyPath: side.other.keyPath].tenths)
  }

  private static func scale(
    _ value: Int, by numerator: Int, over denominator: Int, rounding rule: FloatingPointRoundingRule
  ) -> Int {
    Int((Double(value * numerator) / Double(denominator)).rounded(rule))
  }
}
