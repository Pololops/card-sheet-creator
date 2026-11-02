import Testing

@testable import CardSheetCreator

@Suite struct ScrollGestureGateTests {
  private var gate = ScrollGestureGate()

  @Test mutating func aClaimAtBeganOwnsTheWholeGesture() {
    let began = gate.verdict(for: .began) { true }
    let changed = gate.verdict(for: .changed) { false }

    #expect(began == .deliver)
    #expect(changed == .deliver)
  }

  @Test mutating func aSlotUnderThePointerMidGestureDoesNotTakeIt() {
    let began = gate.verdict(for: .began) { false }
    let changed = gate.verdict(for: .changed) { true }

    #expect(began == .pass)
    #expect(changed == .pass)
  }

  @Test mutating func endedReleasesTheGesture() {
    _ = gate.verdict(for: .began) { true }

    let ended = gate.verdict(for: .ended) { false }
    let next = gate.verdict(for: .changed) { true }

    #expect(ended == .deliver)
    #expect(next == .pass)
  }

  @Test mutating func cancelledReleasesTheGesture() {
    _ = gate.verdict(for: .began) { true }

    let cancelled = gate.verdict(for: .cancelled) { false }
    let next = gate.verdict(for: .changed) { true }

    #expect(cancelled == .deliver)
    #expect(next == .pass)
  }

  @Test mutating func momentumAfterAnOwnedGestureIsSwallowed() {
    _ = gate.verdict(for: .began) { true }
    _ = gate.verdict(for: .ended) { false }

    let first = gate.verdict(for: .momentum) { false }
    let second = gate.verdict(for: .momentum) { false }

    #expect(first == .swallow)
    #expect(second == .swallow)
  }

  @Test mutating func momentumAfterAPassedGestureScrollsThePage() {
    _ = gate.verdict(for: .began) { false }
    _ = gate.verdict(for: .ended) { false }

    let momentum = gate.verdict(for: .momentum) { false }

    #expect(momentum == .pass)
  }

  @Test mutating func aNewGestureResetsTheMomentumState() {
    _ = gate.verdict(for: .began) { true }
    _ = gate.verdict(for: .ended) { false }
    _ = gate.verdict(for: .began) { false }
    _ = gate.verdict(for: .ended) { false }

    let momentum = gate.verdict(for: .momentum) { false }

    #expect(momentum == .pass)
  }
}
