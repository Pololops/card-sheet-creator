import Domain
import Foundation
import Printing
import Testing

@testable import CardSheetCreator

/// A calibration flow wired to a real library, a hand-wound clock and the stub printer, with the
/// gestures a user makes between steps.
@MainActor
struct CalibrationRig {
  static let canon = "Canon G5000 series"
  static let epson = "Epson XP-2100"

  let model: ColorCalibrationModel
  let printer: StubPrintService
  let library: LibraryModel
  let clock: TestClock
  let sheetID: UUID

  static func driver(_ fingerprint: String) -> DriverSettings {
    DriverSettings(data: Data(fingerprint.utf8), fingerprint: fingerprint)
  }

  static func make(
    saved: PrintSettings = PrintSettings(printerName: canon), launchPrinter: String? = canon,
    printers: [String] = [canon, epson], withSheets: Bool = true
  ) async throws -> CalibrationRig {
    let (_, library, sheet) = try await TestLibrary.sheetWithOneImage()
    library.savePrintSettings(saved)
    let printer = StubPrintService(
      printers: printers, fingerprints: [canon: "canon-1", epson: "epson-1"])
    let clock = TestClock()
    let launch = ColorCalibrationRoute.Launch(
      printerName: launchPrinter, sheetIDs: withSheets ? [sheet.id] : [])
    let model = ColorCalibrationModel(
      launch: launch, library: library, printService: printer, now: { clock.now })
    return CalibrationRig(model: model, printer: printer, library: library, clock: clock, sheetID: sheet.id)
  }

  func tickScreenChecklist() {
    for check in ColorCalibrationModel.ScreenCheck.allCases { model.setScreenCheck(check, isOn: true) }
  }

  func startPrinting() {
    tickScreenChecklist()
    model.continueToPrint()
  }

  func waitForInkToDry() {
    clock.advance(by: ColorCalibrationModel.dryingDuration)
    model.finishDrying()
  }

  func startComparing() async {
    startPrinting()
    await model.printChart()
    waitForInkToDry()
    model.startComparing()
  }

  /// Picks the printed centre patch in every remaining round, so the result stays at the session centre.
  func pickNeutralPatches() {
    while let round = model.session?.currentRound { model.pick(round.neutralVariant) }
  }

  func pick(_ letter: Character, of round: CalibrationRound) throws {
    model.pick(try #require(round.variants.first { $0.letter == letter }))
  }

  /// Brightness at G (three steps above the centre), every other round at the centre: a brightness of 3.
  func complete() async throws {
    await startComparing()
    try pick("G", of: .brightness)
    pickNeutralPatches()
  }
}
