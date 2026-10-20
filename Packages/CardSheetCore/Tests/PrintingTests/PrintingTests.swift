import AppKit
import Domain
import Testing

@testable import Printing

@Suite struct PaperSelectionTests {
  @Test func plainA4IsPreferredOverItsBorderlessVariant() {
    let papers = [
      Paper(id: "iso-a4-borderless", name: "A4 (sans marges)"),
      Paper(id: "iso-a4", name: "A4"),
      Paper(id: "na-letter", name: "US Letter"),
    ]

    #expect(PaperSelection.standardA4(in: papers)?.id == "iso-a4")
  }

  @Test(arguments: ["A4.Borderless", "A4.FB", "iso_a4_210x297mm.Fullbleed"])
  func borderlessOnlyDriverYieldsNoPaper(id: String) {
    #expect(PaperSelection.standardA4(in: [Paper(id: id, name: "A4")]) == nil)
  }

  @Test func driverSpecificA4IdIsRecognised() {
    let papers = [Paper(id: "iso_a4_210x297mm", name: "A4")]

    #expect(PaperSelection.standardA4(in: papers)?.id == "iso_a4_210x297mm")
  }
}

@Suite struct PrintQualityTests {
  @Test func qualityMapsToIPPValues() {
    #expect(PrintQuality.draft.ippValue == "3")
    #expect(PrintQuality.best.ippValue == "5")
  }
}

@MainActor @Suite struct PrintInfoTests {
  @Test func printInfoKeepsTheExactSizeOfTheSheet() {
    let info = AppKitPrintService().makePrintInfo(settings: PrintSettings())

    #expect(info.topMargin == 0 && info.bottomMargin == 0 && info.leftMargin == 0 && info.rightMargin == 0)
    #expect(info.scalingFactor == 1)
    #expect(info.horizontalPagination == .clip && info.verticalPagination == .clip)
    #expect(info.orientation == .portrait)
  }
}
