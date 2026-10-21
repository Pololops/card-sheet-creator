import AppKit
import Domain

/// Settings as the print panel hands them back, built by PrintCore itself so no printer is needed.
final class PanelSettings {
  enum Value: Sendable {
    case number(Int32)
    case text(String)
    case flag(Bool)
  }

  static let mappingType = "com.apple.print.PageToPaperMappingType"
  static let layoutEnabled = "com.apple.print.PrintSettings.PMLayoutNUp"
  static let layoutRows = "com.apple.print.PrintSettings.PMLayoutRows"
  static let layoutColumns = "com.apple.print.PrintSettings.PMLayoutColumns"

  let raw: PMPrintSettings

  init(_ entries: [String: Value] = [:], pages: ClosedRange<UInt32>? = nil) {
    var created: PMPrintSettings?
    guard PMCreatePrintSettings(&created) == noErr, let created else {
      preconditionFailure("PrintCore could not create print settings")
    }
    raw = created
    Self.apply(entries, to: raw)
    if let pages {
      PMSetFirstPage(raw, pages.lowerBound, false)
      PMSetLastPage(raw, pages.upperBound, false)
    }
  }

  /// What the printer would see if this stored choice were restored.
  init(restoring driver: DriverSettings) {
    var restored: PMPrintSettings?
    guard PMPrintSettingsCreateWithDataRepresentation(driver.data as CFData, &restored) == noErr,
      let restored
    else { preconditionFailure("The stored driver settings are unreadable") }
    raw = restored
  }

  deinit { PMRelease(UnsafeRawPointer(raw)) }

  static func apply(_ entries: [String: Value], to settings: PMPrintSettings) {
    for (key, value) in entries {
      PMPrintSettingsSetValue(settings, key as CFString, object(for: value), false)
    }
  }

  func driverSettings(fingerprint: String = "Test Printer|1.0") -> DriverSettings {
    var data: Unmanaged<CFData>?
    guard PMPrintSettingsCreateDataRepresentation(raw, &data, kPMDataFormatXMLCompressed) == noErr,
      let data
    else { preconditionFailure("PrintCore could not serialise print settings") }
    return DriverSettings(data: data.takeRetainedValue() as Data, fingerprint: fingerprint)
  }

  var copies: UInt32 {
    var copies: UInt32 = 0
    PMGetCopies(raw, &copies)
    return copies
  }

  func number(_ key: String) -> Int? { (Self.storedValue(key, in: raw) as? NSNumber)?.intValue }

  private static func object(for value: Value) -> CFTypeRef {
    switch value {
    case .number(var number): CFNumberCreate(nil, .sInt32Type, &number)
    case .text(let text): text as CFString
    case .flag(let flag): flag ? kCFBooleanTrue : kCFBooleanFalse
    }
  }

  static func storedValue(_ key: String, in settings: PMPrintSettings) -> AnyObject? {
    var value: Unmanaged<CFTypeRef>?
    guard PMPrintSettingsGetValue(settings, key as CFString, &value) == noErr else { return nil }
    return value?.takeUnretainedValue()
  }
}

func storedText(_ key: String, in info: NSPrintInfo) -> String? {
  PanelSettings.storedValue(key, in: OpaquePointer(info.pmPrintSettings())) as? String
}

func storedNumber(_ key: String, in info: NSPrintInfo) -> Int? {
  (PanelSettings.storedValue(key, in: OpaquePointer(info.pmPrintSettings())) as? NSNumber)?.intValue
}
