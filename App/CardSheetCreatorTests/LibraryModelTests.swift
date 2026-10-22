import Domain
import Foundation
import Storage
import Testing

@testable import CardSheetCreator

@MainActor @Suite struct LibraryModelTests {
  private let root: URL
  private let picked: URL

  init() throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    root = base.appendingPathComponent("Library")
    picked = base.appendingPathComponent("Contes du soir")
    try FileManager.default.createDirectory(at: picked, withIntermediateDirectories: true)
  }

  private func makeModel() async -> (LibraryModel, UndoManager) {
    let model = LibraryModel(persistence: FileLibraryStore(root: root, debounce: .seconds(60)))
    let undo = UndoManager()
    undo.groupsByEvent = false
    await model.load()
    return (model, undo)
  }

  private func reloadedSnapshot(of model: LibraryModel) async throws -> LibrarySnapshot {
    try await model.flush()
    return try await FileLibraryStore(root: root).loadAll()
  }

  /// Only the change under test is recorded: without the run loop there is no automatic undo group.
  private func undoable(_ undo: UndoManager, on model: LibraryModel, _ change: () -> Void) {
    model.undoManager = undo
    undo.beginUndoGrouping()
    change()
    undo.endUndoGrouping()
  }

  private func pickedImages(_ count: Int) throws -> [URL] {
    try (0..<count).map { index in
      try TestImages.png(at: picked.appendingPathComponent("carte\(index).png"), gray: Double(index) / 20)
    }
  }

  @Test func firstLaunchSeedsTheStandardTemplate() async throws {
    let (model, _) = await makeModel()

    #expect(model.templates.map(\.name) == ["Carte standard"])
    #expect(model.templates.first?.geometry == SheetGeometry(slot: .standardCard))
    #expect(try await reloadedSnapshot(of: model).templates.count == 1)
  }

  @Test func editingATemplateIsSavedWithoutAnyAction() async throws {
    let (model, _) = await makeModel()
    let template = try #require(model.templates.first)
    let wider = SheetGeometry(slot: SlotSize(width: .init(tenths: 600), height: .init(tenths: 856)))

    model.updateGeometry(ofTemplate: template.id, to: wider)

    #expect(try await reloadedSnapshot(of: model).templates.first?.geometry == wider)
  }

  @Test func undoRestoresThePreviousSlotSize() async throws {
    let (model, undo) = await makeModel()
    let template = try #require(model.templates.first)
    let wider = SheetGeometry(slot: SlotSize(width: .init(tenths: 600), height: .init(tenths: 856)))

    undoable(undo, on: model) { model.updateGeometry(ofTemplate: template.id, to: wider) }
    undo.undo()

    #expect(model.templates.first?.geometry == template.geometry)
    #expect(try await reloadedSnapshot(of: model).templates.first?.geometry == template.geometry)
  }

  @Test func deletingIsUndoneWithUndo() async throws {
    let (model, undo) = await makeModel()
    let template = try #require(model.templates.first)

    undoable(undo, on: model) { model.delete([.template(template.id)]) }
    #expect(model.templates.isEmpty)
    undo.undo()

    #expect(model.templates == [template])
  }

  @Test func picturesFromAFolderBecomeNamedSheets() async throws {
    let (model, _) = await makeModel()
    let template = try #require(model.templates.first)

    let sheets = await model.createSheets(from: try pickedImages(10), template: template)

    #expect(sheets.map(\.name) == ["Contes du soir 1/2", "Contes du soir 2/2"])
    #expect(model.selection == [.sheet(sheets[0].id)])
    #expect(model.importSummary?.createdSheets == 2)
    #expect(try await reloadedSnapshot(of: model).sheets.count == 2)
  }

  @Test func droppingACropUpdatesEveryClone() async throws {
    let (model, _) = await makeModel()
    let template = try #require(model.templates.first)
    let sheet = try #require(await model.createSheets(from: try pickedImages(1), template: template).first)
    let image = try #require(sheet.images.first)
    let anchor = CropAnchor(x: 0.1, y: 0.5)

    model.setCrop(anchor, for: image, inSheet: sheet.id)

    let updated = try #require(model.sheet(id: sheet.id))
    #expect(try updated.slotContents().allSatisfy { $0.map(updated.crop(for:)) == anchor })
  }

  @Test func undoingACropRestoresTheCenteredFraming() async throws {
    let (model, undo) = await makeModel()
    let template = try #require(model.templates.first)
    let sheet = try #require(await model.createSheets(from: try pickedImages(1), template: template).first)
    let image = try #require(sheet.images.first)

    undoable(undo, on: model) { model.setCrop(CropAnchor(x: 0.1, y: 0.5), for: image, inSheet: sheet.id) }
    undo.undo()

    #expect(model.sheet(id: sheet.id)?.crop(for: image) == .centered)
  }

  @Test func validatingAResizeOffersToSaveTheSizeAsATemplate() async throws {
    let (model, _) = await makeModel()
    let template = try #require(model.templates.first)
    let sheet = try #require(await model.createSheets(from: try pickedImages(9), template: template).first)
    let draft = ResizeDraft(sheet: sheet)
    draft.geometry = SheetGeometry(slot: SlotSize(width: .init(tenths: 660), height: .init(tenths: 900)))

    let outcome = try model.applyResize(draft)

    #expect(outcome.movedCount == 3)
    #expect(model.sheets.count == 2)
    #expect(model.pendingTemplateOffer?.geometry == draft.geometry)
  }

  @Test func cancellingAResizeLeavesTheSheetUntouched() async throws {
    let (model, _) = await makeModel()
    let template = try #require(model.templates.first)
    let sheet = try #require(await model.createSheets(from: try pickedImages(9), template: template).first)
    let draft = ResizeDraft(sheet: sheet)

    draft.geometry = SheetGeometry(slot: SlotSize(width: .init(tenths: 660), height: .init(tenths: 900)))

    #expect(model.sheet(id: sheet.id) == sheet)
    #expect(draft.movedCount == 3)
  }

  @Test func acceptingTheOfferCreatesABlankTemplate() async throws {
    let (model, _) = await makeModel()
    let template = try #require(model.templates.first)
    let sheet = try #require(await model.createSheets(from: try pickedImages(2), template: template).first)
    let draft = ResizeDraft(sheet: sheet)
    draft.geometry = SheetGeometry(slot: SlotSize(width: .init(tenths: 660), height: .init(tenths: 900)))
    _ = try model.applyResize(draft)

    model.acceptTemplateOffer(named: "Carte 66 × 90")

    #expect(model.templates.map(\.name).contains("Carte 66 × 90"))
    #expect(model.pendingTemplateOffer == nil)
  }

  private func settingsWithTwoPrinters() -> PrintSettings {
    let driver = DriverSettings(data: Data("old".utf8), fingerprint: "old")
    let calibration = PrinterCalibration(
      correction: ColorCorrection(brightness: 1), calibratedAt: Date(timeIntervalSince1970: 1_000),
      driver: nil, fingerprint: nil, quality: .best)
    return PrintSettings(
      printerName: "Canon", quality: .draft, driverSettings: ["Canon": driver, "Epson": driver],
      colorCalibrations: ["Canon": calibration, "Epson": calibration])
  }

  @Test func savingAColorCalibrationChangesOnlyItsPrinter() async throws {
    let (model, _) = await makeModel()
    let before = settingsWithTwoPrinters()
    model.savePrintSettings(before)
    let renewed = PrinterCalibration(
      correction: ColorCorrection(contrast: -2), calibratedAt: Date(timeIntervalSince1970: 2_000),
      driver: nil, fingerprint: "epson-1", quality: .best)

    model.saveColorCalibration(renewed, forPrinter: "Epson")

    var expected = before
    expected.colorCalibrations["Epson"] = renewed
    #expect(model.printSettings == expected)
    #expect(try await reloadedSnapshot(of: model).printSettings == expected)
  }

  @Test func savingDriverSettingsChangesOnlyItsPrinter() async throws {
    let (model, _) = await makeModel()
    let before = settingsWithTwoPrinters()
    model.savePrintSettings(before)
    let renewed = DriverSettings(data: Data("new".utf8), fingerprint: "new")

    model.saveDriverSettings(renewed, forPrinter: "Epson")

    var expected = before
    expected.driverSettings["Epson"] = renewed
    #expect(model.printSettings == expected)
    #expect(try await reloadedSnapshot(of: model).printSettings == expected)
  }
}
