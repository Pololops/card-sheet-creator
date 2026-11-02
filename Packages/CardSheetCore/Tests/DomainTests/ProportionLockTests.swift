import Testing

@testable import Domain

@Suite struct ProportionLockTests {
  private let minimum = GridLayout.minimumSlotSide
  private let usable = SlotSize(width: Millimeters(tenths: 2000), height: Millimeters(tenths: 2870))

  private func slot(_ width: Int, _ height: Int) -> SlotSize {
    SlotSize(width: Millimeters(tenths: width), height: Millimeters(tenths: height))
  }

  /// One accepted edit, as the view performs it.
  private func edit(
    _ lock: inout ProportionLock, _ current: SlotSize, _ side: SlotSide, to tenths: Int
  ) -> SlotSize {
    var applied = current
    lock.resize(current, setting: side, to: Millimeters(tenths: tenths)) { slot in
      applied = slot
      return true
    }
    return applied
  }

  @Test func widthDrivesHeightFromTheRatio() {
    var lock = ProportionLock()

    let next = edit(&lock, .standardCard, .width, to: 630)

    #expect(next == slot(630, 999))
  }

  @Test func heightDrivesWidthFromTheRatio() {
    var lock = ProportionLock()

    let next = edit(&lock, .standardCard, .height, to: 999)

    #expect(next == slot(630, 999))
  }

  @Test func halfTenthRoundsAwayFromZero() {
    var lock = ProportionLock()

    let next = edit(&lock, slot(200, 300), .width, to: 303)

    #expect(next.height == Millimeters(tenths: 455))
  }

  @Test func followingEditsKeepTheFirstReference() {
    var lock = ProportionLock()

    let first = edit(&lock, .standardCard, .width, to: 100)
    let second = edit(&lock, first, .width, to: 1800)

    #expect(first == slot(100, 159))
    #expect(second == slot(1800, 2853))
  }

  @Test func steppingBackAndForthReturnsToTheStart() {
    var lock = ProportionLock()
    var current = SlotSize.standardCard

    for _ in 0..<10 { current = edit(&lock, current, .width, to: current.width.tenths + 5) }
    for _ in 0..<10 { current = edit(&lock, current, .width, to: current.width.tenths - 5) }

    #expect(current == .standardCard)
  }

  @Test func writingTheCurrentValueLeavesTheSlotUntouched() {
    var lock = ProportionLock()
    let stepped = edit(&lock, .standardCard, .height, to: 871)

    let next = lock.resized(stepped, setting: .width, to: stepped.width)

    #expect(next == stepped)
  }

  @Test func refusedEditKeepsTheReference() {
    var lock = ProportionLock()
    let first = edit(&lock, .standardCard, .width, to: 100)
    lock.resize(first, setting: .width, to: Millimeters(tenths: 1800)) { _ in false }

    let next = edit(&lock, first, .width, to: 1800)

    #expect(next == slot(1800, 2853))
  }

  @Test func aSlotChangedElsewhereBecomesTheNewReference() {
    var lock = ProportionLock()
    _ = edit(&lock, .standardCard, .width, to: 630)

    let next = lock.resized(slot(500, 500), setting: .width, to: Millimeters(tenths: 600))

    #expect(next == slot(600, 600))
  }

  @Test func rangeNarrowsTheWidthOfATallSlot() {
    let lock = ProportionLock()

    let range = lock.range(of: .width, for: .standardCard, minimum: minimum, maximum: usable)

    #expect(range == Millimeters(tenths: 100)...Millimeters(tenths: 1810))
  }

  @Test func rangeNarrowsTheHeightOfATallSlot() {
    let lock = ProportionLock()

    let range = lock.range(of: .height, for: .standardCard, minimum: minimum, maximum: usable)

    #expect(range == Millimeters(tenths: 159)...Millimeters(tenths: 2870))
  }

  @Test func rangeFollowsTheReferenceAfterAnEdit() {
    var lock = ProportionLock()
    let first = edit(&lock, .standardCard, .width, to: 100)

    let range = lock.range(of: .width, for: first, minimum: minimum, maximum: usable)

    #expect(range == Millimeters(tenths: 100)...Millimeters(tenths: 1810))
  }

  @Test(arguments: [SlotSide.width, SlotSide.height])
  func derivedSideStaysWithinBoundsAtTheRangeEdges(side: SlotSide) throws {
    let lock = ProportionLock()
    let range = try #require(lock.range(of: side, for: .standardCard, minimum: minimum, maximum: usable))

    for edge in [range.lowerBound, range.upperBound] {
      let next = lock.resized(.standardCard, setting: side, to: edge)

      #expect(next.width >= minimum && next.width <= usable.width)
      #expect(next.height >= minimum && next.height <= usable.height)
    }
  }

  @Test(arguments: [(0, 856), (10, 3000), (Int.max / 2, 600)])
  func slotOutsideTheUsableAreaHasNoRange(width: Int, height: Int) {
    let lock = ProportionLock()

    let range = lock.range(of: .width, for: slot(width, height), minimum: minimum, maximum: usable)

    #expect(range == nil)
  }

  @Test func resizingADegenerateSlotLeavesTheOtherSideUntouched() {
    let lock = ProportionLock()

    let next = lock.resized(slot(0, 856), setting: .width, to: Millimeters(tenths: 500))

    #expect(next == slot(500, 856))
  }

  @Test func scalingKeepsTheRatio() {
    let result = ProportionLock.scaled(.standardCard, by: 1.5, minimum: minimum, maximum: usable)

    #expect(result?.slot == slot(810, 1284))
    #expect(result?.isAtLimit == false)
  }

  @Test func scalingByOneLeavesTheSlotUnchanged() {
    let result = ProportionLock.scaled(.standardCard, by: 1, minimum: minimum, maximum: usable)

    #expect(result?.slot == .standardCard)
    #expect(result?.isAtLimit == false)
  }

  @Test func scalingStopsAtTheMinimumSide() {
    let result = ProportionLock.scaled(.standardCard, by: 0.1, minimum: minimum, maximum: usable)

    #expect(result?.slot == slot(100, 159))
    #expect(result?.isAtLimit == true)
  }

  @Test func scalingStopsAtTheUsableArea() {
    let result = ProportionLock.scaled(.standardCard, by: 10, minimum: minimum, maximum: usable)

    #expect(result?.slot == slot(1810, 2869))
    #expect(result?.isAtLimit == true)
  }

  @Test func scalingFromTheSameStartDoesNotDrift() {
    let wandering = [1.1, 1.4, 0.7, 2.0].compactMap {
      ProportionLock.scaled(.standardCard, by: $0, minimum: minimum, maximum: usable)
    }

    let settled = ProportionLock.scaled(.standardCard, by: 1.5, minimum: minimum, maximum: usable)

    #expect(wandering.count == 4)
    #expect(settled?.slot == slot(810, 1284))
  }

  @Test func scalingADegenerateSlotGivesNothing() {
    let result = ProportionLock.scaled(slot(0, 856), by: 1.5, minimum: minimum, maximum: usable)

    #expect(result == nil)
  }

  @Test(arguments: [0.0, -1.0, Double.nan])
  func scalingByANonPositiveFactorGivesNothing(factor: Double) {
    let result = ProportionLock.scaled(.standardCard, by: factor, minimum: minimum, maximum: usable)

    #expect(result == nil)
  }
}
