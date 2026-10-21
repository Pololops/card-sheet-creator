import Foundation
import Testing

@testable import Printing

@Suite struct PrinterColorSupportTests {
  private func ppd(_ colorDeviceLine: String) -> Data {
    Data("*PPD-Adobe: \"4.3\"\n*FileVersion: \"1.0\"\n\(colorDeviceLine)\n*DefaultResolution: 600dpi\n".utf8)
  }

  @Test(arguments: [
    ("*ColorDevice: False", false),
    ("*ColorDevice:   False", false),
    ("*ColorDevice: True", true),
    ("*cupsICCProfile sRGB..../sRGB: \"/path\"", true),
  ])
  func colorDeviceFlagDecides(line: String, isColor: Bool) {
    #expect(PrinterColorSupport.isColor(ppd: ppd(line)) == isColor)
  }

  @Test func unknownDescriptionCountsAsColor() {
    #expect(PrinterColorSupport.isColor(ppd: nil))
  }
}
