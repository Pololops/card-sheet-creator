import AppKit
import Domain

/// A choice from the print panel that would change the printed card size.
public enum ExactSizeOverride: CaseIterable, Hashable, Sendable {
  case scaleToFit
  case pagesPerSheet
}

/// Keeps every print at the exact size of the sheet, whatever the driver settings restored beneath it.
/// All PrintCore access goes through the PM APIs: the `NSPrintInfo.printSettings` dictionary mangles
/// dotted keys.
enum ExactSizeGuard {
  private enum Key {
    static let mappingType = "com.apple.print.PageToPaperMappingType"
    static let layoutEnabled = "com.apple.print.PrintSettings.PMLayoutNUp"
    static let layoutRows = "com.apple.print.PrintSettings.PMLayoutRows"
    static let layoutColumns = "com.apple.print.PrintSettings.PMLayoutColumns"
    static let fitToPage = "fit-to-page"
    static let printScaling = "print-scaling"
  }

  private static let scalingValuesThatResize: Set<String> = ["fit", "fill", "auto-fit"]
  private static let allPages = UInt32(truncatingIfNeeded: kPMPrintAllPages)

  static func overrides(in settings: PMPrintSettings) -> Set<ExactSizeOverride> {
    var found: Set<ExactSizeOverride> = []
    if scalesToFit(settings) { found.insert(.scaleToFit) }
    if hasSeveralPagesPerSheet(settings) { found.insert(.pagesPerSheet) }
    return found
  }

  static func resetLayout(_ settings: PMPrintSettings) {
    setNumber(Int32(kPMPageToPaperMappingNone.rawValue), for: Key.mappingType, in: settings)
    PMPrintSettingsSetValue(settings, Key.layoutEnabled as CFString, kCFBooleanFalse, false)
    setNumber(1, for: Key.layoutRows, in: settings)
    setNumber(1, for: Key.layoutColumns, in: settings)
    PMPrintSettingsSetValue(settings, Key.fitToPage as CFString, "false" as CFString, false)
    PMPrintSettingsSetValue(settings, Key.printScaling as CFString, "none" as CFString, false)
    PMSetFirstPage(settings, 1, false)
    PMSetLastPage(settings, allPages, false)
  }

  /// `false` when the stored data can't be read, so the caller falls back to the app's own settings.
  static func restore(_ driver: DriverSettings, into info: NSPrintInfo) -> Bool {
    var restored: PMPrintSettings?
    guard PMPrintSettingsCreateWithDataRepresentation(driver.data as CFData, &restored) == noErr,
      let restored
    else { return false }
    defer { PMRelease(UnsafeRawPointer(restored)) }
    PMCopyPrintSettings(restored, OpaquePointer(info.pmPrintSettings()))
    info.updateFromPMPrintSettings()
    return true
  }

  /// Must be the last mutation before the info reaches the print operation: anything applied after it
  /// could bring scaling, paper or page range back.
  static func enforce(on info: NSPrintInfo, copies: Int) {
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
    let settings = OpaquePointer(info.pmPrintSettings())
    resetLayout(settings)
    PMSetCopies(settings, UInt32(copies), false)
    info.updateFromPMPrintSettings()
  }

  private static func scalesToFit(_ settings: PMPrintSettings) -> Bool {
    if let mapping = value(Key.mappingType, in: settings) as? NSNumber,
      mapping.intValue == kPMPageToPaperMappingScaleToFit.rawValue
    {
      return true
    }
    if value(Key.fitToPage, in: settings) as? String == "true" { return true }
    return (value(Key.printScaling, in: settings) as? String).map(scalingValuesThatResize.contains) ?? false
  }

  private static func hasSeveralPagesPerSheet(_ settings: PMPrintSettings) -> Bool {
    if (value(Key.layoutEnabled, in: settings) as? NSNumber)?.boolValue == true { return true }
    let rows = (value(Key.layoutRows, in: settings) as? NSNumber)?.intValue ?? 1
    let columns = (value(Key.layoutColumns, in: settings) as? NSNumber)?.intValue ?? 1
    return rows * columns > 1
  }

  private static func value(_ key: String, in settings: PMPrintSettings) -> AnyObject? {
    var stored: Unmanaged<CFTypeRef>?
    guard PMPrintSettingsGetValue(settings, key as CFString, &stored) == noErr else { return nil }
    return stored?.takeUnretainedValue()
  }

  private static func setNumber(_ number: Int32, for key: String, in settings: PMPrintSettings) {
    var number = number
    PMPrintSettingsSetValue(settings, key as CFString, CFNumberCreate(nil, .sInt32Type, &number), false)
  }

  private static func selectStandardA4(in info: NSPrintInfo) {
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
}
