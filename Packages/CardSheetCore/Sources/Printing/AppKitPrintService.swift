import AppKit
import Domain
import PDFKit

public enum PrintError: Error, Equatable, Sendable {
  case unreadableDocument
  case printerUnavailable(String)
  case failed
}

@MainActor
public protocol PrintService {
  func printerNames() -> [String]
  var defaultPrinterName: String? { get }
  func isReady(printerNamed name: String) -> Bool?
  func print(pdfAt url: URL, settings: PrintSettings) throws
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
    var list: Unmanaged<CFArray>?
    guard PMServerCreatePrinterList(nil, &list) == noErr, let printers = list?.takeRetainedValue() else {
      return nil
    }
    for index in 0..<CFArrayGetCount(printers) {
      guard let raw = CFArrayGetValueAtIndex(printers, index) else { continue }
      let printer = OpaquePointer(raw)
      guard let printerName = PMPrinterGetName(printer) as String?, printerName == name
      else { continue }
      var state = PMPrinterState(kPMPrinterIdle)
      guard PMPrinterGetState(printer, &state) == noErr else { return nil }
      return state != PMPrinterState(kPMPrinterStopped)
    }
    return nil
  }

  public func print(pdfAt url: URL, settings: PrintSettings) throws {
    if let name = settings.printerName, NSPrinter(name: name) == nil {
      throw PrintError.printerUnavailable(name)
    }
    guard let document = PDFDocument(url: url) else { throw PrintError.unreadableDocument }
    guard
      let operation = document.printOperation(
        for: makePrintInfo(settings: settings), scalingMode: .pageScaleNone, autoRotate: false)
    else { throw PrintError.failed }
    operation.showsPrintPanel = false
    operation.showsProgressPanel = true
    guard operation.run() else { throw PrintError.failed }
  }

  func makePrintInfo(settings: PrintSettings) -> NSPrintInfo {
    let info = NSPrintInfo()
    if let name = settings.printerName, let printer = NSPrinter(name: name) {
      info.printer = printer
    }
    selectStandardA4(in: info)
    info.orientation = .portrait
    info.topMargin = 0
    info.bottomMargin = 0
    info.leftMargin = 0
    info.rightMargin = 0
    info.scalingFactor = 1
    info.horizontalPagination = .clip
    info.verticalPagination = .clip
    info.isHorizontallyCentered = false
    info.isVerticallyCentered = false
    applyQuality(settings.quality, to: info)
    return info
  }

  private func selectStandardA4(in info: NSPrintInfo) {
    info.paperSize = NSSize(width: Page.a4.width.points, height: Page.a4.height.points)
    let session = OpaquePointer(info.pmPrintSession())
    var printer: PMPrinter?
    var paperList: Unmanaged<CFArray>?
    guard PMSessionGetCurrentPrinter(session, &printer) == noErr, let printer,
      PMPrinterGetPaperList(printer, &paperList) == noErr, let paperArray = paperList?.takeUnretainedValue()
    else { return }
    let papers: [PMPaper] = (0..<CFArrayGetCount(paperArray)).compactMap { index in
      CFArrayGetValueAtIndex(paperArray, index).map { OpaquePointer($0) }
    }

    let candidates = papers.map { paper in
      var id: Unmanaged<CFString>?
      var name: Unmanaged<CFString>?
      _ = PMPaperGetID(paper, &id)
      _ = PMPaperCreateLocalizedName(paper, printer, &name)
      return Paper(
        id: id?.takeUnretainedValue() as String? ?? "", name: name?.takeRetainedValue() as String? ?? "")
    }
    guard let chosen = PaperSelection.standardA4(in: candidates),
      let index = candidates.firstIndex(of: chosen)
    else { return }

    var format: PMPageFormat?
    guard PMCreatePageFormatWithPMPaper(&format, papers[index]) == noErr, let format else { return }
    defer { PMRelease(UnsafeRawPointer(format)) }
    PMCopyPageFormat(format, OpaquePointer(info.pmPageFormat()))
    info.updateFromPMPageFormat()
  }

  /// Best effort: drivers that don't know these keys simply print at their default quality.
  private func applyQuality(_ quality: PrintQuality, to info: NSPrintInfo) {
    let settings = OpaquePointer(info.pmPrintSettings())
    PMPrintSettingsSetValue(settings, "print-quality" as CFString, quality.ippValue as CFString, false)
    PMPrintSettingsSetValue(settings, "cupsPrintQuality" as CFString, quality.cupsValue as CFString, false)
    info.updateFromPMPrintSettings()
  }
}
