public struct SemanticVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
  public let major: Int
  public let minor: Int
  public let patch: Int

  public init(major: Int, minor: Int, patch: Int) {
    self.major = major
    self.minor = minor
    self.patch = patch
  }

  public init?(_ text: String) {
    return nil
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    false
  }

  public var description: String { "" }
}
