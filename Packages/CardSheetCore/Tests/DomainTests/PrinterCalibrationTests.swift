import Foundation
import Testing

@testable import Domain

@Suite struct PrinterCalibrationTests {
  private static let driver = DriverSettings(data: Data([1]), fingerprint: "canon-1")
  private static let otherDriver = DriverSettings(data: Data([2]), fingerprint: "canon-1")

  private let calibration = PrinterCalibration(
    correction: ColorCorrection(brightness: 2), calibratedAt: .distantPast, driver: Self.driver,
    fingerprint: "canon-1", quality: .best)

  @Test func newCalibrationIsApplied() {
    #expect(calibration.isApplied)
  }

  @Test func unchangedSetupIsNotOutdated() {
    #expect(!calibration.isOutdated(driver: Self.driver, fingerprint: "canon-1", quality: .best))
  }

  @Test(arguments: [
    (otherDriver, "canon-1", PrintQuality.best),
    (driver, "canon-1", PrintQuality.draft),
    (driver, "canon-2", PrintQuality.best),
  ])
  func changedSetupIsOutdated(driver: DriverSettings?, fingerprint: String?, quality: PrintQuality) {
    #expect(calibration.isOutdated(driver: driver, fingerprint: fingerprint, quality: quality))
  }

  @Test func unreachablePrinterIsNotOutdated() {
    #expect(!calibration.isOutdated(driver: Self.driver, fingerprint: nil, quality: .best))
  }
}
