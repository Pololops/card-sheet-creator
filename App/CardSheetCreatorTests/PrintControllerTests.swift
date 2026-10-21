import Domain
import Foundation
import Printing
import Storage
import Testing

@testable import CardSheetCreator

/// Stands in for the system at the printer boundary: queues, drivers, the panel and the paper.
@MainActor
private final class StubPrintService: PrintService {
  var printers: [String]
  var fingerprints: [String: String]
  var panelChoice: DriverChoice?
  private(set) var printedCopies: [Int] = []

  init(printers: [String], fingerprints: [String: String]) {
    self.printers = printers
    self.fingerprints = fingerprints
  }

  var defaultPrinterName: String? { printers.first }
  func printerNames() -> [String] { printers }
  func isReady(printerNamed name: String) -> Bool? { true }
  func driverFingerprint(printerNamed name: String) -> String? { fingerprints[name] }
  func chooseDriverSettings(for settings: PrintSettings, copies: Int) -> DriverChoice? { panelChoice }

  func print(pdfAt url: URL, settings: PrintSettings, copies: Int) throws {
    printedCopies.append(copies)
  }
}

@MainActor @Suite struct PrintControllerTests {
  private static let canon = "Canon G5000 series"
  private static let epson = "Epson XP-2100"

  private func driver(_ fingerprint: String) -> DriverSettings {
    DriverSettings(data: Data(fingerprint.utf8), fingerprint: fingerprint)
  }

  private func choice(
    for printer: String = canon, fingerprint: String = "canon-1", copies: Int = 1,
    overrides: Set<ExactSizeOverride> = []
  ) -> DriverChoice {
    DriverChoice(
      printerName: printer, driver: driver(fingerprint), copies: copies, overrides: overrides)
  }

  private func makeController(
    saved: PrintSettings = PrintSettings(printerName: canon),
    printers: [String] = [canon, epson],
    fingerprints: [String: String] = [canon: "canon-1", epson: "epson-1"]
  ) async throws -> (controller: PrintController, printer: StubPrintService) {
    let (store, _, sheet) = try await TestLibrary.sheetWithOneImage()
    let printer = StubPrintService(printers: printers, fingerprints: fingerprints)
    let controller = PrintController(
      sheets: [sheet], saved: saved, printService: printer, persistence: store)
    return (controller, printer)
  }

  @Test func applyingThePanelActivatesDriverSettings() async throws {
    let (controller, printer) = try await makeController()
    printer.panelChoice = choice()

    controller.editDriverSettings()

    #expect(controller.isDriverControlled)
    #expect(controller.settings.driverSettings[Self.canon] == driver("canon-1"))
  }

  @Test func choosingAnotherPrinterInThePanelMovesThePicker() async throws {
    let (controller, printer) = try await makeController()
    printer.printers = [Self.canon, Self.epson, "HP LaserJet"]
    printer.panelChoice = choice(for: Self.epson, fingerprint: "epson-1")

    controller.editDriverSettings()

    #expect(controller.settings.printerName == Self.epson)
    #expect(controller.printers == [Self.canon, Self.epson, "HP LaserJet"])
  }

  @Test func cancellingThePanelKeepsPreviousSettings() async throws {
    let (controller, printer) = try await makeController()
    printer.panelChoice = choice(copies: 3, overrides: [.scaleToFit])
    controller.editDriverSettings()
    let before = (controller.settings, controller.copies, controller.overrides)
    printer.panelChoice = nil

    controller.editDriverSettings()

    #expect(controller.settings == before.0)
    #expect(controller.copies == before.1)
    #expect(controller.overrides == before.2)
  }

  @Test func changedDriverDropsAdvancedSettingsOnOpen() async throws {
    let saved = PrintSettings(
      printerName: Self.canon, quality: .draft, driverSettings: [Self.canon: driver("canon-0")])

    let (controller, _) = try await makeController(saved: saved)

    #expect(controller.settings.driverSettings.isEmpty)
    #expect(controller.settings.quality == .draft)
    #expect(controller.wasDriverReset)
    #expect(!controller.isDriverControlled)
  }

  @Test func unreachablePrinterLeavesAdvancedSettingsInactive() async throws {
    let saved = PrintSettings(printerName: Self.canon, driverSettings: [Self.canon: driver("canon-1")])

    let (controller, _) = try await makeController(saved: saved, fingerprints: [:])

    #expect(controller.settings.driverSettings[Self.canon] == driver("canon-1"))
    #expect(!controller.isDriverControlled)
    #expect(!controller.wasDriverReset)
  }

  @Test func applyingForgetsTheDriverChangedNotice() async throws {
    let saved = PrintSettings(printerName: Self.canon, driverSettings: [Self.canon: driver("canon-0")])
    let (controller, printer) = try await makeController(saved: saved)
    printer.panelChoice = choice()

    controller.editDriverSettings()

    #expect(!controller.wasDriverReset)
  }

  @Test func switchingPrinterKeepsOtherPrintersSettings() async throws {
    let saved = PrintSettings(
      printerName: Self.canon,
      driverSettings: [Self.canon: driver("canon-1"), Self.epson: driver("epson-1")])
    let (controller, _) = try await makeController(saved: saved)

    controller.selectPrinter(Self.epson)

    #expect(controller.settings.driverSettings.count == 2)
    #expect(controller.isDriverControlled)
  }

  @Test func resettingRemovesOnlySelectedPrintersSettings() async throws {
    let saved = PrintSettings(
      printerName: Self.canon,
      driverSettings: [Self.canon: driver("canon-1"), Self.epson: driver("epson-1")])
    let (controller, _) = try await makeController(saved: saved)

    controller.resetDriverSettings()

    #expect(controller.settings.driverSettings == [Self.epson: driver("epson-1")])
    #expect(!controller.isDriverControlled)
  }

  @Test func overridesAreForgottenWhenThePrinterChanges() async throws {
    let (controller, printer) = try await makeController()
    printer.panelChoice = choice(overrides: [.scaleToFit, .pagesPerSheet])
    controller.editDriverSettings()

    controller.selectPrinter(Self.epson)

    #expect(controller.overrides.isEmpty)
  }

  @Test func panelCopiesReachThePrinter() async throws {
    let (controller, printer) = try await makeController()
    printer.panelChoice = choice(copies: 3)
    controller.editDriverSettings()

    let didPrint = await controller.print()

    #expect(didPrint)
    #expect(printer.printedCopies == [3])
  }

  @Test func copiesAreBackToOneAfterReset() async throws {
    let (controller, printer) = try await makeController()
    printer.panelChoice = choice(copies: 3)
    controller.editDriverSettings()

    controller.resetDriverSettings()
    _ = await controller.print()

    #expect(printer.printedCopies == [1])
  }
}
