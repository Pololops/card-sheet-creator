import Foundation

/// Whether a queue prints in colour, read from its PPD. A missing PPD (AirPrint queues, an unreachable
/// printer) counts as colour: asking a black-and-white printer for colour rounds only costs a fruitless
/// comparison, while hiding them from a colour printer would leave it uncalibrated.
enum PrinterColorSupport {
  static func isColor(ppd: Data?) -> Bool {
    guard let ppd else { return true }
    return String(decoding: ppd, as: UTF8.self).firstMatch(of: /\*ColorDevice:\s*False/) == nil
  }
}
