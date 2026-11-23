public struct SemanticVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
  public let major: Int
  public let minor: Int
  public let patch: Int

  public init(major: Int, minor: Int, patch: Int) {
    self.major = major
    self.minor = minor
    self.patch = patch
  }

  /// Accepts only `x.y.z`, optionally prefixed by a lowercase `v` (the release tag convention).
  /// Anything looser (pre-release suffixes, extra components, signs) is refused so that a
  /// crafted tag can never compare as newer by accident.
  public init?(_ text: String) {
    let numbers = text.hasPrefix("v") ? text.dropFirst() : Substring(text)
    let components = numbers.split(separator: ".", omittingEmptySubsequences: false)
    guard components.count == 3,
      let major = Self.component(components[0]),
      let minor = Self.component(components[1]),
      let patch = Self.component(components[2])
    else { return nil }
    self.init(major: major, minor: minor, patch: patch)
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
  }

  public var description: String { "\(major).\(minor).\(patch)" }

  private static let asciiDigits = UInt8(ascii: "0")...UInt8(ascii: "9")

  /// ASCII digits only, no leading zero except a lone `0`; `Int` parsing returns nil on overflow.
  private static func component(_ text: Substring) -> Int? {
    guard !text.isEmpty, text.utf8.allSatisfy(asciiDigits.contains) else { return nil }
    guard text == "0" || !text.hasPrefix("0") else { return nil }
    return Int(text)
  }
}
