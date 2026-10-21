import Foundation

public enum PrintQuality: String, Hashable, Sendable, Codable, CaseIterable {
  case draft
  case best
}

/// A printer's advanced driver choices, opaque to the domain. The fingerprint identifies the driver
/// they were made for, so they can be dropped when the driver changes.
public struct DriverSettings: Hashable, Sendable, Codable {
  public var data: Data
  public var fingerprint: String

  public init(data: Data, fingerprint: String) {
    self.data = data
    self.fingerprint = fingerprint
  }
}

/// The user's last print choices. Codable so V2 can save it as a reusable print profile.
public struct PrintSettings: Hashable, Sendable, Codable {
  public var printerName: String?
  public var quality: PrintQuality
  public var driverSettings: [String: DriverSettings]

  public init(
    printerName: String? = nil, quality: PrintQuality = .best, driverSettings: [String: DriverSettings] = [:]
  ) {
    self.printerName = printerName
    self.quality = quality
    self.driverSettings = driverSettings
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    printerName = try container.decodeIfPresent(String.self, forKey: .printerName)
    quality = try container.decode(PrintQuality.self, forKey: .quality)
    // settings.json written before ADR 0011 has no driverSettings key.
    driverSettings =
      try container.decodeIfPresent([String: DriverSettings].self, forKey: .driverSettings) ?? [:]
  }
}
