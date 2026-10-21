import Domain
import Foundation
import Observation
import Printing
import Rendering
import Storage

/// Renders the selected sheets to one PDF, then prints it at 100 % or saves it.
@Observable
final class PrintController {
  let sheets: [Sheet]
  private(set) var printers: [String]
  var settings: PrintSettings
  /// Copies chosen in the print panel: they only last for this dialog, never reaching `settings`.
  private(set) var copies = 1
  /// Panel choices the exact-size guarantee refused; shown once, never persisted.
  private(set) var overrides: Set<ExactSizeOverride> = []
  private(set) var wasDriverReset = false
  private(set) var failure: String?
  private(set) var isWorking = false

  /// Looked up when the printer changes, not while rendering: asking the driver is slow.
  @ObservationIgnored private var fingerprint: String?
  @ObservationIgnored private let printService: any PrintService
  @ObservationIgnored private let renderer: SheetRenderer

  init(
    sheets: [Sheet], saved: PrintSettings, printService: any PrintService, persistence: any LibraryPersistence
  ) {
    self.sheets = sheets
    self.printService = printService
    let printers = printService.printerNames()
    var settings = saved
    if settings.printerName.map(printers.contains) != true {
      settings.printerName = printService.defaultPrinterName ?? printers.first
    }
    self.printers = printers
    self.settings = settings
    renderer = SheetRenderer(imageURL: { persistence.imageURL(for: $0) })
    refreshDriverState()
  }

  var title: String { "Imprimer \(sheets.count) planche\(sheets.count > 1 ? "s" : "")" }
  var isPrinterReady: Bool? { settings.printerName.flatMap(printService.isReady(printerNamed:)) }

  /// An unreachable printer (no fingerprint) keeps its stored settings, but they stay inactive.
  var isDriverControlled: Bool {
    guard let name = settings.printerName, let stored = settings.driverSettings[name] else { return false }
    return stored.fingerprint == fingerprint
  }

  var colorCalibration: PrinterCalibration? {
    settings.printerName.flatMap { settings.colorCalibrations[$0] }
  }

  /// A printer that was never calibrated invites the user to do it, every time the dialog opens.
  var offersColorCalibration: Bool { !printers.isEmpty && colorCalibration == nil }

  /// The correction is kept when the printer's setup changed since it was measured, only flagged.
  var isColorCalibrationOutdated: Bool {
    colorCalibration?.isOutdated(
      driver: controlledDriver, fingerprint: fingerprint, quality: settings.quality)
      ?? false
  }

  /// Only the PDF sent to the printer is corrected; saved PDFs stay as designed.
  private var printedCorrection: ColorCorrection {
    guard let calibration = colorCalibration, calibration.isApplied else { return .neutral }
    return calibration.correction
  }

  private var controlledDriver: DriverSettings? {
    guard isDriverControlled, let name = settings.printerName else { return nil }
    return settings.driverSettings[name]
  }

  /// Slot size of the first sheet, quoted in the size guarantee.
  var cardSize: String {
    guard let slot = sheets.first?.geometry.slot else { return "" }
    return "\(slot.width.formatted) × \(slot.height.formatted) mm"
  }

  func selectPrinter(_ name: String?) {
    settings.printerName = name
    overrides = []
    copies = 1
    wasDriverReset = false
    refreshDriverState()
  }

  func editDriverSettings() {
    guard let choice = printService.chooseDriverSettings(for: settings, copies: copies) else { return }
    printers = printService.printerNames()
    settings.printerName = choice.printerName
    settings.driverSettings[choice.printerName] = choice.driver
    copies = choice.copies
    overrides = choice.overrides
    fingerprint = choice.driver.fingerprint
    wasDriverReset = false
  }

  func resetDriverSettings() {
    guard let name = settings.printerName else { return }
    settings.driverSettings[name] = nil
    overrides = []
    copies = 1
    wasDriverReset = false
  }

  func setCorrectionApplied(_ isApplied: Bool) {
    guard let name = settings.printerName else { return }
    settings.colorCalibrations[name]?.isApplied = isApplied
  }

  func resetColorCalibration() {
    guard let name = settings.printerName else { return }
    settings.colorCalibrations[name] = nil
  }

  func print() async -> Bool {
    await run { url in
      try await renderer.renderPDF(try pages(), to: url, correction: printedCorrection)
      try printService.print(pdfAt: url, settings: settings, copies: copies)
    }
  }

  func exportPDF(to destination: URL) async -> Bool {
    await run { _ in try await renderer.renderPDF(try pages(), to: destination) }
  }

  /// Drops the printer's advanced settings once its driver is known to have changed.
  private func refreshDriverState() {
    guard let name = settings.printerName else {
      fingerprint = nil
      return
    }
    fingerprint = printService.driverFingerprint(printerNamed: name)
    guard let fingerprint, let stored = settings.driverSettings[name], stored.fingerprint != fingerprint
    else { return }
    settings.driverSettings[name] = nil
    wasDriverReset = true
  }

  private func pages() throws -> [RenderPage] {
    try sheets.map { try RenderPage(sheet: $0) }
  }

  private func run(_ work: (URL) async throws -> Void) async -> Bool {
    isWorking = true
    failure = nil
    defer { isWorking = false }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "CardSheetCreator-\(UUID().uuidString).pdf")
    defer { try? FileManager.default.removeItem(at: url) }
    do {
      try await work(url)
      return true
    } catch {
      failure = Self.message(for: error)
      return false
    }
  }

  static func message(for error: Error) -> String {
    switch error {
    case RenderError.unreadableImage(let image):
      "Image introuvable : \(image.originalName). L'impression est bloquée tant que l'image manque."
    case PrintError.printerUnavailable(let name):
      "L'imprimante « \(name) » n'est plus disponible. Choisis-en une autre."
    case PrintError.failed:
      "L'impression a échoué. Vérifie l'imprimante, puis réessaie."
    default:
      "Impossible de préparer l'impression : \(error.localizedDescription)"
    }
  }
}
