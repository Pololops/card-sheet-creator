import CoreGraphics
import Domain
import Foundation
import Observation
import Printing
import Rendering

/// The colour calibration, step by step: print a chart, pick the patches that match the screen, save the
/// correction. It owns a local printer choice and never writes the print dialog's printer.
@Observable
final class ColorCalibrationModel {
  enum Step: Hashable {
    case prepare, print, compare, verify, done
  }

  /// What the user confirms about the screen: a chart judged on a tinted or dimming screen is worthless.
  enum ScreenCheck: CaseIterable, Hashable {
    case nightShift, trueTone, autoBrightness, whiteMatchesPaper
  }

  /// Home inkjet ink needs about a minute before it stops shifting; the wait cannot be skipped.
  static let dryingDuration: TimeInterval = 60

  private(set) var step = Step.prepare
  private(set) var screenChecks: Set<ScreenCheck> = []
  private(set) var printers: [String]
  private(set) var printerName: String?
  private(set) var session: CalibrationSession?
  private(set) var failure: String?
  private(set) var isPrinting = false
  private(set) var isInkWet = false
  private(set) var dryingEndsAt: Date?

  @ObservationIgnored private let launch: ColorCalibrationRoute.Launch
  @ObservationIgnored private let library: LibraryModel
  @ObservationIgnored private let printService: any PrintService
  @ObservationIgnored private let now: () -> Date

  init(
    launch: ColorCalibrationRoute.Launch, library: LibraryModel, printService: any PrintService,
    now: @escaping () -> Date = Date.init
  ) {
    self.launch = launch
    self.library = library
    self.printService = printService
    self.now = now
    let printers = printService.printerNames()
    self.printers = printers
    printerName = Self.initialPrinter(launch: launch, among: printers, printService: printService)
  }

  // MARK: - Préparer

  var isPrinterReady: Bool? { printerName.flatMap(printService.isReady(printerNamed:)) }
  var isColorPrinter: Bool { printerName.map(printService.isColorPrinter(named:)) ?? true }
  var canContinueToPrint: Bool { printerName != nil && screenChecks.count == ScreenCheck.allCases.count }

  func selectPrinter(_ name: String?) {
    printerName = name
  }

  func setScreenCheck(_ check: ScreenCheck, isOn: Bool) {
    if isOn { screenChecks.insert(check) } else { screenChecks.remove(check) }
  }

  /// The panel's copies and overrides are ignored: the chart is one copy and overrides are already stripped.
  func chooseDriverOptions() {
    guard let printerName,
      let choice = printService.chooseDriverSettings(for: settings(for: printerName), copies: 1)
    else { return }
    library.saveDriverSettings(choice.driver, forPrinter: choice.printerName)
    printers = printService.printerNames()
    self.printerName = choice.printerName
  }

  func continueToPrint() {
    guard step == .prepare, canContinueToPrint else { return }
    step = .print
  }

  // MARK: - Imprimer

  /// Once a chart is out the sheet is in the user's hands: going back would orphan it.
  func goBackToPrepare() {
    guard step == .print, !isPrinting, dryingEndsAt == nil else { return }
    step = .prepare
  }

  var canStartComparing: Bool { step == .print && dryingEndsAt != nil && !isInkWet }

  func printChart() async {
    guard step == .print else { return }
    let session = CalibrationSession(
      rounds: CalibrationRound.rounds(isColorPrinter: isColorPrinter),
      startingFrom: savedCorrection ?? .neutral)
    self.session = session
    await send { url in
      try await ColorChart.renderPDF(to: url, centre: session.centre, rounds: session.rounds)
    }
  }

  func finishDrying() {
    guard isInkWet, let dryingEndsAt, now() >= dryingEndsAt else { return }
    isInkWet = false
  }

  func startComparing() {
    guard canStartComparing else { return }
    step = .compare
  }

  // MARK: - Comparer

  var canUndoPick: Bool { step == .compare && session?.picks.isEmpty == false }

  func pick(_ variant: ChartVariant) {
    guard step == .compare, var session else { return }
    session.pick(variant)
    self.session = session
    guard session.isComplete else { return }
    save(session.result)
    // The chart's drying is over: Vérifier tells "not printed yet" from "drying" by this date.
    dryingEndsAt = nil
    step = .verify
  }

  func undoLastPick() {
    guard canUndoPick, var session else { return }
    session.undoLastPick()
    self.session = session
  }

  func referenceImage(for round: CalibrationRound) -> CGImage? {
    try? ColorChart.referenceImage(for: round)
  }

  // MARK: - Vérifier

  func printVerification() async {
    guard step == .verify, let session else { return }
    await send { url in
      try await ColorChart.renderVerificationPDF(to: url, correction: session.result, rounds: session.rounds)
    }
  }

  /// Every round starts again from the saved result, so the chart brackets what was just measured.
  func refine() {
    guard step == .verify, !isInkWet else { return }
    session = nil
    dryingEndsAt = nil
    failure = nil
    step = .print
  }

  func finish() {
    guard step == .verify, !isInkWet else { return }
    step = .done
  }

  // MARK: - C'est réglé

  var result: ColorCorrection? { session?.result }
  var diagnosis: String? { result.map(CorrectionDiagnosis.sentence(for:)) }
  var canPrintAfterwards: Bool { !launch.sheetIDs.isEmpty }

  var handoff: ColorCalibrationRoute.Handoff? {
    canPrintAfterwards
      ? ColorCalibrationRoute.Handoff(sheetIDs: launch.sheetIDs, printerName: launch.printerName) : nil
  }

  // MARK: - Printing

  private var savedCorrection: ColorCorrection? {
    printerName.flatMap { library.printSettings.colorCalibrations[$0]?.correction }
  }

  private static func initialPrinter(
    launch: ColorCalibrationRoute.Launch, among printers: [String], printService: any PrintService
  ) -> String? {
    guard !printers.isEmpty else { return nil }
    if let requested = launch.printerName, printers.contains(requested) { return requested }
    return printService.defaultPrinterName ?? printers.first
  }

  /// The printer's saved quality and driver options, with the window's own printer: the dialog's choice
  /// stays untouched.
  private func settings(for printerName: String) -> PrintSettings {
    var settings = library.printSettings
    settings.printerName = printerName
    return settings
  }

  private func send(rendering render: (URL) async throws -> Void) async {
    guard let printerName, !isPrinting else { return }
    isPrinting = true
    failure = nil
    defer { isPrinting = false }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "CardSheetCreator-\(UUID().uuidString).pdf")
    defer { try? FileManager.default.removeItem(at: url) }
    do {
      try await render(url)
      try printService.print(pdfAt: url, settings: settings(for: printerName), copies: 1)
      isInkWet = true
      dryingEndsAt = now().addingTimeInterval(Self.dryingDuration)
    } catch {
      failure = PrintController.message(for: error)
    }
  }

  // MARK: - Saving

  private func save(_ correction: ColorCorrection) {
    guard let printerName else { return }
    let fingerprint = printService.driverFingerprint(printerNamed: printerName)
    let calibration = PrinterCalibration(
      correction: correction, calibratedAt: now(),
      driver: matchingDriver(of: printerName, fingerprint: fingerprint), fingerprint: fingerprint,
      quality: library.printSettings.quality)
    library.saveColorCalibration(calibration, forPrinter: printerName)
  }

  /// A stored entry from another driver is dropped by the dialog, so recording it would warn for nothing.
  private func matchingDriver(of printerName: String, fingerprint: String?) -> DriverSettings? {
    guard let stored = library.printSettings.driverSettings[printerName], stored.fingerprint == fingerprint
    else { return nil }
    return stored
  }
}
