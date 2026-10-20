public enum PrintQuality: String, Hashable, Sendable, Codable, CaseIterable {
  case draft
  case best
}

/// The user's last print choices. Codable so V2 can save it as a reusable print profile.
public struct PrintSettings: Hashable, Sendable, Codable {
  public var printerName: String?
  public var quality: PrintQuality

  public init(printerName: String? = nil, quality: PrintQuality = .best) {
    self.printerName = printerName
    self.quality = quality
  }
}
