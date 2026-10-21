import Domain
import Foundation
import Printing
import Testing

@testable import CardSheetCreator

@MainActor @Suite struct ColorCalibrationModelTests {
  private static let canon = CalibrationRig.canon
  private static let epson = CalibrationRig.epson

  private func driver(_ fingerprint: String) -> DriverSettings {
    CalibrationRig.driver(fingerprint)
  }

  // MARK: - Préparer

  @Test func printingNeedsTheScreenChecklist() async throws {
    let rig = try await CalibrationRig.make()
    let (model, printer) = (rig.model, rig.printer)
    model.setScreenCheck(.nightShift, isOn: true)
    model.setScreenCheck(.trueTone, isOn: true)
    model.setScreenCheck(.autoBrightness, isOn: true)

    model.continueToPrint()
    await model.printChart()
    #expect(!model.canContinueToPrint)
    #expect(model.step == .prepare)
    #expect(printer.printedCopies.isEmpty)

    model.setScreenCheck(.whiteMatchesPaper, isOn: true)
    model.continueToPrint()

    #expect(model.canContinueToPrint)
    #expect(model.step == .print)
  }

  @Test func menuLaunchWithoutPrintersCannotPrint() async throws {
    let rig = try await CalibrationRig.make(launchPrinter: nil, printers: [], withSheets: false)
    rig.tickScreenChecklist()

    rig.model.continueToPrint()

    #expect(rig.model.printerName == nil)
    #expect(!rig.model.canContinueToPrint)
    #expect(rig.model.step == .prepare)
  }

  @Test func windowPrinterChoiceLeavesTheDialogPrinterAlone() async throws {
    let rig = try await CalibrationRig.make()
    rig.model.selectPrinter(Self.epson)

    await rig.startComparing()
    rig.pickNeutralPatches()

    #expect(rig.printer.printedSettings.map(\.printerName) == [Self.epson])
    #expect(rig.library.printSettings.printerName == Self.canon)
    #expect(Set(rig.library.printSettings.colorCalibrations.keys) == [Self.epson])
  }

  @Test func driverOptionsChosenHereAreSavedForThatPrinterOnly() async throws {
    let saved = PrintSettings(printerName: Self.canon, driverSettings: [Self.canon: driver("canon-1")])
    let rig = try await CalibrationRig.make(saved: saved)
    rig.printer.panelChoice = DriverChoice(
      printerName: Self.epson, driver: driver("epson-1"), copies: 3, overrides: [.scaleToFit])

    rig.model.chooseDriverOptions()

    #expect(rig.model.printerName == Self.epson)
    let expected = [Self.canon: driver("canon-1"), Self.epson: driver("epson-1")]
    #expect(rig.library.printSettings.driverSettings == expected)
    #expect(rig.library.printSettings.printerName == Self.canon)
  }

  // MARK: - Imprimer

  @Test func chartPrintsOneCopyWithThePrintersSavedSettings() async throws {
    let saved = PrintSettings(
      printerName: Self.canon, quality: .draft, driverSettings: [Self.canon: driver("canon-1")])
    let rig = try await CalibrationRig.make(saved: saved)
    rig.startPrinting()

    await rig.model.printChart()

    #expect(rig.printer.printedCopies == [1])
    #expect(rig.printer.printedSettings == [saved])
    #expect(rig.printer.printedPDFs.last?.starts(with: Data("%PDF".utf8)) == true)
    #expect(rig.model.isInkWet)
    #expect(rig.model.dryingEndsAt == rig.clock.now.addingTimeInterval(ColorCalibrationModel.dryingDuration))
  }

  @Test func comparingWaitsForTheInkToDry() async throws {
    let rig = try await CalibrationRig.make()
    rig.startPrinting()
    await rig.model.printChart()

    rig.model.startComparing()
    #expect(rig.model.step == .print)

    rig.clock.advance(by: ColorCalibrationModel.dryingDuration - 1)
    rig.model.finishDrying()
    rig.model.startComparing()
    #expect(rig.model.isInkWet)
    #expect(rig.model.step == .print)

    rig.clock.advance(by: 1)
    rig.model.finishDrying()
    rig.model.startComparing()
    #expect(!rig.model.isInkWet)
    #expect(rig.model.step == .compare)
  }

  @Test func failedChartPrintCanBeRetried() async throws {
    let rig = try await CalibrationRig.make()
    rig.startPrinting()
    rig.printer.failure = .failed

    await rig.model.printChart()

    #expect(rig.model.failure != nil)
    #expect(!rig.model.isInkWet)
    #expect(!rig.model.isPrinting)
    #expect(rig.model.step == .print)

    rig.printer.failure = nil
    await rig.model.printChart()

    #expect(rig.model.failure == nil)
    #expect(rig.model.isInkWet)
  }

  @Test func blackAndWhitePrinterIsCalibratedInTwoRounds() async throws {
    let rig = try await CalibrationRig.make()
    rig.printer.colorPrinters = []

    await rig.startComparing()

    #expect(!rig.model.isColorPrinter)
    #expect(rig.model.session?.rounds == [.brightness, .contrast])
    rig.pickNeutralPatches()
    #expect(rig.model.step == .verify)
  }

  // MARK: - Comparer

  @Test func completingTheRoundsSavesAnAppliedCorrection() async throws {
    let saved = PrintSettings(
      printerName: Self.canon, quality: .draft, driverSettings: [Self.canon: driver("canon-1")])
    let rig = try await CalibrationRig.make(saved: saved)

    try await rig.complete()

    let expected = PrinterCalibration(
      correction: ColorCorrection(brightness: 3), isApplied: true, calibratedAt: rig.clock.now,
      driver: driver("canon-1"), fingerprint: "canon-1", quality: .draft)
    #expect(rig.library.printSettings.colorCalibrations[Self.canon] == expected)
    #expect(rig.model.step == .verify)
  }

  @Test func staleDriverEntryIsNotRecorded() async throws {
    let saved = PrintSettings(printerName: Self.canon, driverSettings: [Self.canon: driver("canon-0")])
    let rig = try await CalibrationRig.make(saved: saved)

    try await rig.complete()

    let calibration = try #require(rig.library.printSettings.colorCalibrations[Self.canon])
    #expect(calibration.driver == nil)
    #expect(calibration.fingerprint == "canon-1")
  }

  @Test func goingBackForgetsTheLastPick() async throws {
    let rig = try await CalibrationRig.make()
    await rig.startComparing()
    #expect(!rig.model.canUndoPick)
    try rig.pick("G", of: .brightness)
    #expect(rig.model.session?.currentRound == .contrast)

    rig.model.undoLastPick()

    #expect(rig.model.session?.currentRound == .brightness)
    #expect(rig.model.session?.picks.isEmpty == true)
    #expect(!rig.model.canUndoPick)
  }

  // MARK: - Vérifier

  @Test func vanishedPrinterKeepsThePicks() async throws {
    let rig = try await CalibrationRig.make()
    try await rig.complete()
    let picks = rig.model.session?.picks
    let saved = rig.library.printSettings.colorCalibrations[Self.canon]
    rig.printer.failure = .printerUnavailable(Self.canon)

    await rig.model.printVerification()

    #expect(rig.model.failure?.contains(Self.canon) == true)
    #expect(rig.model.session?.picks == picks)
    #expect(rig.library.printSettings.colorCalibrations[Self.canon] == saved)
    #expect(!rig.model.isInkWet)

    rig.printer.failure = nil
    await rig.model.printVerification()

    #expect(rig.model.failure == nil)
    #expect(rig.model.isInkWet)
  }

  @Test func refiningStartsFromTheSavedCorrection() async throws {
    let rig = try await CalibrationRig.make()
    try await rig.complete()

    rig.model.refine()
    await rig.model.printChart()

    #expect(rig.model.step == .print)
    #expect(rig.model.session?.centre == ColorCorrection(brightness: 3))
    #expect(rig.model.session?.picks.isEmpty == true)
    #expect(rig.model.session?.rounds == CalibrationRound.allCases)
  }

  // MARK: - C'est réglé

  @Test func confirmingTheResultShowsItsDiagnosis() async throws {
    let rig = try await CalibrationRig.make()
    try await rig.complete()

    rig.model.finish()

    #expect(rig.model.step == .done)
    #expect(rig.model.diagnosis == CorrectionDiagnosis.sentence(for: ColorCorrection(brightness: 3)))
  }

  @Test func finishingHandsTheLaunchSheetsBackToThePrintDialog() async throws {
    let rig = try await CalibrationRig.make(launchPrinter: Self.epson)

    #expect(rig.model.canPrintAfterwards)
    let expected = ColorCalibrationRoute.Handoff(sheetIDs: [rig.sheetID], printerName: Self.epson)
    #expect(rig.model.handoff == expected)
  }

  @Test func menuLaunchHasNothingToPrintAfterwards() async throws {
    let rig = try await CalibrationRig.make(withSheets: false)

    #expect(!rig.model.canPrintAfterwards)
    #expect(rig.model.handoff == nil)
  }
}
