import AppKit

/// Runs `body` on the named print queue, keeping PrintCore's printer list alive meanwhile.
/// `nil` when the queue can't be found.
func withPrinter<Result>(named name: String, _ body: (PMPrinter) -> Result) -> Result? {
  var list: Unmanaged<CFArray>?
  guard PMServerCreatePrinterList(nil, &list) == noErr, let printers = list?.takeRetainedValue() else {
    return nil
  }
  for index in 0..<CFArrayGetCount(printers) {
    guard let raw = CFArrayGetValueAtIndex(printers, index) else { continue }
    let printer = OpaquePointer(raw)
    if PMPrinterGetName(printer) as String? == name { return body(printer) }
  }
  return nil
}

/// Identifies the driver behind a queue, so settings made for one driver never reach another.
/// AirPrint queues have no PPD: they are identified by their make and model alone.
enum PrinterFingerprint {
  static func make(makeAndModel: String, ppd: Data?) -> String {
    guard let ppd, let version = fileVersion(in: ppd) else { return makeAndModel }
    return "\(makeAndModel)|\(version)"
  }

  /// `nil` when the printer can't be reached.
  static func current(printerNamed name: String) -> String? {
    withPrinter(named: name) { printer in
      var makeAndModel: Unmanaged<CFString>?
      guard PMPrinterGetMakeAndModelName(printer, &makeAndModel) == noErr,
        let model = makeAndModel?.takeUnretainedValue() as String?
      else { return nil }
      return make(makeAndModel: model, ppd: ppdData(of: printer))
    } ?? nil
  }

  private static func fileVersion(in ppd: Data) -> String? {
    let text = String(decoding: ppd, as: UTF8.self)
    return text.firstMatch(of: /\*FileVersion:\s*"([^"]*)"/).map { String($0.1) }
  }

  private static func ppdData(of printer: PMPrinter) -> Data? {
    var url: Unmanaged<CFURL>?
    var data: Unmanaged<CFData>?
    guard PMPrinterCopyDescriptionURL(printer, kPMPPDDescriptionType as CFString, &url) == noErr, let url,
      PMCopyPPDData(url.takeRetainedValue(), &data) == noErr
    else { return nil }
    return data?.takeRetainedValue() as Data?
  }
}
