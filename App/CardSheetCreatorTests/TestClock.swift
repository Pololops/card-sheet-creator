import Foundation

/// A hand-wound clock: tests move time forward instead of sleeping.
final class TestClock {
  private(set) var now = Date(timeIntervalSince1970: 1_000_000)

  func advance(by seconds: TimeInterval) {
    now = now.addingTimeInterval(seconds)
  }
}
