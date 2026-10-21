import Foundation

/// The colour correction measured for one printer, with the setup it was measured on, so the app can
/// tell when that setup has since changed.
public struct PrinterCalibration: Hashable, Sendable, Codable {
  public var correction: ColorCorrection
  /// Switched off in the print dialog without forgetting the correction.
  public var isApplied: Bool
  public var calibratedAt: Date
  public var driver: DriverSettings?
  public var fingerprint: String?
  public var quality: PrintQuality

  public init(
    correction: ColorCorrection, isApplied: Bool = true, calibratedAt: Date, driver: DriverSettings?,
    fingerprint: String?, quality: PrintQuality
  ) {
    self.correction = correction
    self.isApplied = isApplied
    self.calibratedAt = calibratedAt
    self.driver = driver
    self.fingerprint = fingerprint
    self.quality = quality
  }

  /// Whether the printer's options, driver or quality differ from what the correction was measured on.
  /// An unreachable printer has no fingerprint to compare, so it never counts as a driver change.
  public func isOutdated(driver: DriverSettings?, fingerprint: String?, quality: PrintQuality) -> Bool {
    if driver != self.driver || quality != self.quality { return true }
    guard let known = self.fingerprint, let current = fingerprint else { return false }
    return known != current
  }
}
