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

@MainActor @Suite struct ExactSizeGuardTests {
  @Test func untouchedSettingsReportNoOverride() {
    let panel = PanelSettings([PanelSettings.mappingType: .number(1), "print-scaling": .text("none")])

    #expect(ExactSizeGuard.overrides(in: panel.raw).isEmpty)
  }

  @Test(arguments: [
    (PanelSettings.mappingType, PanelSettings.Value.number(2)),
    ("fit-to-page", .text("true")),
    ("print-scaling", .text("fit")),
    ("print-scaling", .text("fill")),
    ("print-scaling", .text("auto-fit")),
  ])
  func scaleToFitIsReported(key: String, value: PanelSettings.Value) {
    let panel = PanelSettings([key: value])

    #expect(ExactSizeGuard.overrides(in: panel.raw) == [.scaleToFit])
  }

  @Test func severalPagesPerSheetIsReported() {
    let panel = PanelSettings([
      PanelSettings.layoutEnabled: .flag(true), PanelSettings.layoutRows: .number(2),
      PanelSettings.layoutColumns: .number(1),
    ])

    #expect(ExactSizeGuard.overrides(in: panel.raw) == [.pagesPerSheet])
  }
}

@MainActor @Suite struct PrintInfoTests {
  private let service = AppKitPrintService()

  private func makePrintInfo(
    driver: DriverSettings? = nil, quality: PrintQuality = .best, copies: Int = 1
  ) -> NSPrintInfo {
    service.makePrintInfo(settings: PrintSettings(quality: quality), driver: driver, copies: copies)
  }

  @Test func printInfoKeepsTheExactSizeOfTheSheet() {
    let info = makePrintInfo()

    #expect(info.topMargin == 0 && info.bottomMargin == 0 && info.leftMargin == 0 && info.rightMargin == 0)
    #expect(info.scalingFactor == 1)
    #expect(info.horizontalPagination == .clip && info.verticalPagination == .clip)
    #expect(info.orientation == .portrait)
    #expect(!info.isHorizontallyCentered && !info.isVerticallyCentered)
  }

  @Test func restoredDriverSettingsReachThePrintInfo() {
    let driver = PanelSettings(["cupsMediaType": .text("photographic")]).driverSettings()

    #expect(storedText("cupsMediaType", in: makePrintInfo(driver: driver)) == "photographic")
  }

  @Test func scaleToFitChosenInThePanelIsUndoneBeforePrinting() {
    let panel = PanelSettings([
      PanelSettings.mappingType: .number(2), "fit-to-page": .text("true"), "print-scaling": .text("fit"),
    ])

    let info = makePrintInfo(driver: panel.driverSettings())

    #expect(storedNumber(PanelSettings.mappingType, in: info) == 1)
    #expect(storedText("fit-to-page", in: info) == "false")
    #expect(storedText("print-scaling", in: info) == "none")
    #expect(info.scalingFactor == 1)
  }

  @Test func pagesPerSheetChosenInThePanelIsUndoneBeforePrinting() {
    let panel = PanelSettings([
      PanelSettings.layoutEnabled: .flag(true), PanelSettings.layoutRows: .number(2),
      PanelSettings.layoutColumns: .number(2),
    ])

    let info = makePrintInfo(driver: panel.driverSettings())

    #expect(storedNumber(PanelSettings.layoutEnabled, in: info) == 0)
    #expect(storedNumber(PanelSettings.layoutRows, in: info) == 1)
    #expect(storedNumber(PanelSettings.layoutColumns, in: info) == 1)
  }

  @Test func restoredPageRangeCoversAllPages() {
    let info = makePrintInfo(driver: PanelSettings(pages: 2...3).driverSettings())

    var first: UInt32 = 0
    var last: UInt32 = 0
    PMGetFirstPage(OpaquePointer(info.pmPrintSettings()), &first)
    PMGetLastPage(OpaquePointer(info.pmPrintSettings()), &last)

    #expect(first == 1)
    // PrintCore reads kPMPrintAllPages back as the largest page number it can hold.
    #expect(last == UInt32(Int32.max))
  }

  @Test func restoredSettingsFromAnotherPaperStillPrintOnA4() {
    let panel = PanelSettings([
      PanelSettings.mappingType: .number(2),
      "com.apple.print.PageToPaperMappingMediaName": .text("na-letter"),
    ])

    let info = makePrintInfo(driver: panel.driverSettings())

    #expect(abs(info.paperSize.width - Page.a4.width.points) < 0.5)
    #expect(abs(info.paperSize.height - Page.a4.height.points) < 0.5)
  }

  @Test func qualityIsLeftToTheDriverWhenDriverSettingsAreActive() {
    let driver = PanelSettings(["print-quality": .text("4")]).driverSettings()

    let info = makePrintInfo(driver: driver, quality: .draft)

    #expect(storedText("print-quality", in: info) == "4")
  }

  @Test func appQualityAppliesWithoutDriverSettings() {
    let info = makePrintInfo(quality: .draft)

    #expect(storedText("print-quality", in: info) == "3")
    #expect(storedText("cupsPrintQuality", in: info) == "Draft")
  }

  @Test func unreadableDriverSettingsFallBackToAppQuality() {
    let unreadable = DriverSettings(data: Data("not a plist".utf8), fingerprint: "Test Printer|1.0")

    let info = makePrintInfo(driver: unreadable, quality: .draft)

    #expect(storedText("print-quality", in: info) == "3")
  }

  @Test func requestedCopiesReachThePrintInfo() {
    let info = makePrintInfo(copies: 3)

    var copies: UInt32 = 0
    PMGetCopies(OpaquePointer(info.pmPrintSettings()), &copies)

    #expect(copies == 3)
  }
}

@Suite struct PrinterFingerprintTests {
  private let ppd = Data("*PPD-Adobe: \"4.3\"\n*FileVersion: \"2.7\"\n*Manufacturer: \"Canon\"".utf8)

  @Test func fingerprintCombinesModelAndPPDFileVersion() {
    let fingerprint = PrinterFingerprint.make(makeAndModel: "Canon G5000 series", ppd: ppd)

    #expect(fingerprint == "Canon G5000 series|2.7")
  }

  @Test(arguments: [nil, Data("*PPD-Adobe: \"4.3\"".utf8)])
  func fingerprintWithoutPPDVersionIsTheModelAlone(ppd: Data?) {
    #expect(PrinterFingerprint.make(makeAndModel: "Canon G5000 series", ppd: ppd) == "Canon G5000 series")
  }
}

@MainActor @Suite struct PanelChoiceTests {
  private let service = AppKitPrintService()

  /// A print info as the panel leaves it after the user pressed "Appliquer".
  private func panelOutput(copies: Int = 1, chosen: [String: PanelSettings.Value] = [:]) -> NSPrintInfo {
    let info = service.makePrintInfo(settings: PrintSettings(), driver: nil, copies: copies)
    PanelSettings.apply(chosen, to: OpaquePointer(info.pmPrintSettings()))
    return info
  }

  private func choice(from info: NSPrintInfo) throws -> DriverChoice {
    try #require(service.makeChoice(from: info, fingerprint: "Test Printer|1.0"))
  }

  @Test func panelCopiesComeBackWithTheChoice() throws {
    #expect(try choice(from: panelOutput(copies: 3)).copies == 3)
  }

  @Test func storedDriverSettingsAlwaysHoldOneCopy() throws {
    let stored = try choice(from: panelOutput(copies: 3)).driver

    #expect(PanelSettings(restoring: stored).copies == 1)
  }

  @Test func panelScaleToFitIsReportedInTheChoice() throws {
    let info = panelOutput(chosen: [PanelSettings.mappingType: .number(2)])

    #expect(try choice(from: info).overrides == [.scaleToFit])
  }

  @Test func storedDriverSettingsNeverScale() throws {
    let info = panelOutput(chosen: [PanelSettings.mappingType: .number(2), "fit-to-page": .text("true")])

    let stored = PanelSettings(restoring: try choice(from: info).driver)

    #expect(stored.number(PanelSettings.mappingType) == 1)
  }

  @Test func choiceRecordsTheDriverItWasMadeFor() throws {
    #expect(try choice(from: panelOutput()).driver.fingerprint == "Test Printer|1.0")
  }
}
