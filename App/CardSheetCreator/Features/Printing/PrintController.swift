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
  let printers: [String]
  var settings: PrintSettings
  private(set) var failure: String?
  private(set) var isWorking = false

  @ObservationIgnored private let printService: any PrintService
  @ObservationIgnored private let renderer: SheetRenderer

  init(
    sheets: [Sheet], saved: PrintSettings, printService: any PrintService, persistence: any LibraryPersistence
  ) {
    self.sheets = sheets
    self.printService = printService
    printers = printService.printerNames()
    var settings = saved
    if settings.printerName.map(printers.contains) != true {
      settings.printerName = printService.defaultPrinterName ?? printers.first
    }
    self.settings = settings
    renderer = SheetRenderer(imageURL: { persistence.imageURL(for: $0) })
  }

  var title: String { "Imprimer \(sheets.count) planche\(sheets.count > 1 ? "s" : "")" }
  var isPrinterReady: Bool? { settings.printerName.flatMap(printService.isReady(printerNamed:)) }

  /// Slot size of the first sheet, quoted in the size guarantee.
  var cardSize: String {
    guard let slot = sheets.first?.geometry.slot else { return "" }
    return "\(slot.width.formatted) × \(slot.height.formatted) mm"
  }

  func print() async -> Bool {
    await run { url in
      try await renderer.renderPDF(try pages(), to: url)
      try printService.print(pdfAt: url, settings: settings)
    }
  }

  func exportPDF(to destination: URL) async -> Bool {
    await run { _ in try await renderer.renderPDF(try pages(), to: destination) }
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

  private static func message(for error: Error) -> String {
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
