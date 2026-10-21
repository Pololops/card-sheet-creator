import Domain
import Foundation
import Printing

@testable import CardSheetCreator

/// Stands in for the system at the printer boundary: queues, drivers, the panel and the paper.
@MainActor
final class StubPrintService: PrintService {
  var printers: [String]
  var fingerprints: [String: String]
  var panelChoice: DriverChoice?
  /// The queues that print in colour; `nil` makes every queue a colour printer.
  var colorPrinters: Set<String>?
  private(set) var printedCopies: [Int] = []

  init(printers: [String], fingerprints: [String: String]) {
    self.printers = printers
    self.fingerprints = fingerprints
  }

  var defaultPrinterName: String? { printers.first }
  func printerNames() -> [String] { printers }
  func isReady(printerNamed name: String) -> Bool? { true }
  func driverFingerprint(printerNamed name: String) -> String? { fingerprints[name] }
  func isColorPrinter(named name: String) -> Bool { colorPrinters?.contains(name) ?? true }
  func chooseDriverSettings(for settings: PrintSettings, copies: Int) -> DriverChoice? { panelChoice }

  func print(pdfAt url: URL, settings: PrintSettings, copies: Int) throws {
    printedCopies.append(copies)
  }
}
