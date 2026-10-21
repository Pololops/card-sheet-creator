import AppKit
import Domain
import PDFKit

public enum PrintError: Error, Equatable, Sendable {
  case unreadableDocument
  case printerUnavailable(String)
  case failed
}

/// What the user confirmed in the print panel, already sanitised for exact-size printing.
public struct DriverChoice: Equatable, Sendable {
  public var printerName: String
  public var driver: DriverSettings
  public var copies: Int
  /// Choices the panel made that exact-size printing refuses; they are not part of `driver`.
  public var overrides: Set<ExactSizeOverride>

  public init(printerName: String, driver: DriverSettings, copies: Int, overrides: Set<ExactSizeOverride>) {
    self.printerName = printerName
    self.driver = driver
    self.copies = copies
    self.overrides = overrides
  }
}

@MainActor
public protocol PrintService {
  func printerNames() -> [String]
  var defaultPrinterName: String? { get }
  func isReady(printerNamed name: String) -> Bool?
  /// `nil` when the printer can't be reached.
  func driverFingerprint(printerNamed name: String) -> String?
  /// Opens the system print panel; `nil` when the user cancels or the printer can't be reached.
  func chooseDriverSettings(for settings: PrintSettings, copies: Int) -> DriverChoice?
  func print(pdfAt url: URL, settings: PrintSettings, copies: Int) throws
}

/// Prints the rendered PDF without the system panel, so nobody can turn on "scale to fit".
@MainActor
public final class AppKitPrintService: PrintService {
  public init() {}

  public func printerNames() -> [String] {
    NSPrinter.printerNames
  }

  public var defaultPrinterName: String? {
    NSPrintInfo.shared.printer.name
  }

  /// `nil` when the queue can't be found; `false` when it is stopped (paused, out of paper, error).
  public func isReady(printerNamed name: String) -> Bool? {
    let isReady = withPrinter(named: name) { printer -> Bool? in
      var state = PMPrinterState(kPMPrinterIdle)
      guard PMPrinterGetState(printer, &state) == noErr else { return nil }
      return state != PMPrinterState(kPMPrinterStopped)
    }
    return isReady ?? nil
  }

  public func driverFingerprint(printerNamed name: String) -> String? {
    PrinterFingerprint.current(printerNamed: name)
  }

  public func chooseDriverSettings(for settings: PrintSettings, copies: Int) -> DriverChoice? {
    let info = makePrintInfo(settings: settings, driver: activeDriver(for: settings), copies: copies)
    let panel = NSPrintPanel()
    panel.options = [.showsCopies]
    panel.setDefaultButtonTitle("Appliquer")
    guard panel.runModal(with: info) == NSApplication.ModalResponse.OK.rawValue,
      let fingerprint = PrinterFingerprint.current(printerNamed: info.printer.name)
    else { return nil }
    return makeChoice(from: info, fingerprint: fingerprint)
  }

  public func print(pdfAt url: URL, settings: PrintSettings, copies: Int) throws {
    if let name = settings.printerName, NSPrinter(name: name) == nil {
      throw PrintError.printerUnavailable(name)
    }
    guard let document = PDFDocument(url: url) else { throw PrintError.unreadableDocument }
    let info = makePrintInfo(settings: settings, driver: activeDriver(for: settings), copies: copies)
    guard let operation = document.printOperation(for: info, scalingMode: .pageScaleNone, autoRotate: false)
    else { throw PrintError.failed }
    operation.showsPrintPanel = false
    operation.showsProgressPanel = true
    guard operation.run() else { throw PrintError.failed }
  }

  /// The order is the invariant: printer, then restored driver settings (or the app's quality), then the
  /// exact-size guard, which has the last word.
  func makePrintInfo(settings: PrintSettings, driver: DriverSettings?, copies: Int) -> NSPrintInfo {
    let info = NSPrintInfo()
    if let name = settings.printerName, let printer = NSPrinter(name: name) {
      info.printer = printer
    }
    let isDriverControlled = driver.map { ExactSizeGuard.restore($0, into: info) } ?? false
    if !isDriverControlled {
      applyQuality(settings.quality, to: info)
    }
    ExactSizeGuard.enforce(on: info, copies: copies)
    return info
  }

  /// Overrides are read on the raw panel output, before the layout is reset and the copies stripped:
  /// the stored data must neither scale nor repeat, whatever the panel was left on.
  func makeChoice(from info: NSPrintInfo, fingerprint: String) -> DriverChoice? {
    let settings = OpaquePointer(info.pmPrintSettings())
    var copies: UInt32 = 1
    PMGetCopies(settings, &copies)
    let overrides = ExactSizeGuard.overrides(in: settings)
    ExactSizeGuard.resetLayout(settings)
    PMSetCopies(settings, 1, false)
    var data: Unmanaged<CFData>?
    guard PMPrintSettingsCreateDataRepresentation(settings, &data, kPMDataFormatXMLCompressed) == noErr,
      let data
    else { return nil }
    let driver = DriverSettings(data: data.takeRetainedValue() as Data, fingerprint: fingerprint)
    return DriverChoice(
      printerName: info.printer.name, driver: driver, copies: Int(copies), overrides: overrides)
  }

  /// Stored driver settings are only trusted while the queue's driver is the one they were made for.
  private func activeDriver(for settings: PrintSettings) -> DriverSettings? {
    guard let name = settings.printerName, let stored = settings.driverSettings[name],
      PrinterFingerprint.current(printerNamed: name) == stored.fingerprint
    else { return nil }
    return stored
  }

  /// Best effort: drivers that don't know these keys simply print at their default quality.
  private func applyQuality(_ quality: PrintQuality, to info: NSPrintInfo) {
    let settings = OpaquePointer(info.pmPrintSettings())
    PMPrintSettingsSetValue(settings, "print-quality" as CFString, quality.ippValue as CFString, false)
    PMPrintSettingsSetValue(settings, "cupsPrintQuality" as CFString, quality.cupsValue as CFString, false)
    info.updateFromPMPrintSettings()
  }
}
