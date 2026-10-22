import Domain
import Foundation
import Observation
import Storage

enum LibraryItem: Hashable {
  case template(UUID)
  case sheet(UUID)
}

/// The whole library as the UI sees it. Every change is saved in the background and can be undone.
@Observable
final class LibraryModel {
  private(set) var templates: [Template] = []
  private(set) var sheets: [Sheet] = []
  var selection: Set<LibraryItem> = []
  private(set) var printSettings = PrintSettings()
  var importSummary: ImportSummary?
  var pendingTemplateOffer: TemplateOffer?
  var saveFailure: String?
  var loadFailure: String?

  @ObservationIgnored var undoManager: UndoManager?
  @ObservationIgnored let persistence: any LibraryPersistence
  @ObservationIgnored let now: () -> Date
  /// Saves run one after another, so an older version can never overwrite a newer one.
  @ObservationIgnored private var saveChain: Task<Void, Never>?

  init(persistence: any LibraryPersistence, now: @escaping () -> Date = Date.init) {
    self.persistence = persistence
    self.now = now
  }

  func load() async {
    do {
      let snapshot = try await persistence.loadAll()
      templates = Self.sortedByRecency(snapshot.templates)
      sheets = Self.sortedByRecency(snapshot.sheets)
      printSettings = snapshot.printSettings
      if templates.isEmpty && sheets.isEmpty {
        let template = Template.standardDefault(id: UUID(), now: now())
        templates = [template]
        persist(from: LibraryState(templates: [], sheets: []))
      }
      selection = templates.first.map { [.template($0.id)] } ?? []
      try await persistence.purgeImages(notIn: Set(sheets.flatMap(\.images).map(\.sha256)))
    } catch {
      loadFailure = error.localizedDescription
    }
  }

  func savePrintSettings(_ settings: PrintSettings) {
    guard settings != printSettings else { return }
    printSettings = settings
    enqueue { await $0.save(settings) }
  }

  /// Narrow writers for the calibration window: they never touch the dialog's printer or quality.
  func saveColorCalibration(_ calibration: PrinterCalibration, forPrinter name: String) {
    var settings = printSettings
    settings.colorCalibrations[name] = calibration
    savePrintSettings(settings)
  }

  func saveDriverSettings(_ driver: DriverSettings, forPrinter name: String) {
    var settings = printSettings
    settings.driverSettings[name] = driver
    savePrintSettings(settings)
  }

  func flush() async throws {
    await saveChain?.value
    try await persistence.flush()
    saveFailure = nil
  }

  func template(id: UUID) -> Template? { templates.first { $0.id == id } }
  func sheet(id: UUID) -> Sheet? { sheets.first { $0.id == id } }

  var selectedTemplate: Template? {
    guard selection.count == 1, case .template(let id)? = selection.first else { return nil }
    return template(id: id)
  }

  var selectedSheet: Sheet? {
    guard selection.count == 1, case .sheet(let id)? = selection.first else { return nil }
    return sheet(id: id)
  }

  /// In sidebar order, so a multi-page print follows what the user sees.
  var selectedSheets: [Sheet] {
    sheets.filter { selection.contains(.sheet($0.id)) }
  }

  // MARK: - Changes

  struct LibraryState {
    var templates: [Template]
    var sheets: [Sheet]
  }

  private var state: LibraryState { LibraryState(templates: templates, sheets: sheets) }

  /// Applies `body`, saves what changed and registers the inverse with the undo manager.
  func change(_ actionName: String, _ body: (inout [Template], inout [Sheet]) -> Void) {
    let before = state
    var nextTemplates = templates
    var nextSheets = sheets
    body(&nextTemplates, &nextSheets)
    apply(LibraryState(templates: nextTemplates, sheets: nextSheets), persistingFrom: before)
    registerUndo(actionName, restoring: before)
  }

  private func apply(_ next: LibraryState, persistingFrom previous: LibraryState) {
    templates = Self.sortedByRecency(next.templates)
    sheets = Self.sortedByRecency(next.sheets)
    persist(from: previous)
  }

  private func registerUndo(_ actionName: String, restoring snapshot: LibraryState) {
    guard let undoManager else { return }
    undoManager.registerUndo(withTarget: self) { model in
      let current = model.state
      model.apply(snapshot, persistingFrom: current)
      model.registerUndo(actionName, restoring: current)
    }
    undoManager.setActionName(actionName)
  }

  private func persist(from previous: LibraryState) {
    let oldTemplates = Dictionary(uniqueKeysWithValues: previous.templates.map { ($0.id, $0) })
    let oldSheets = Dictionary(uniqueKeysWithValues: previous.sheets.map { ($0.id, $0) })
    let changedTemplates = templates.filter { oldTemplates[$0.id] != $0 }
    let changedSheets = sheets.filter { oldSheets[$0.id] != $0 }
    let removedTemplates = Set(oldTemplates.keys).subtracting(templates.map(\.id))
    let removedSheets = Set(oldSheets.keys).subtracting(sheets.map(\.id))

    enqueue { persistence in
      for template in changedTemplates { await persistence.save(template) }
      for sheet in changedSheets { await persistence.save(sheet) }
      for id in removedTemplates { await persistence.deleteTemplate(id: id) }
      for id in removedSheets { await persistence.deleteSheet(id: id) }
    }
  }

  func enqueue(_ work: @escaping @Sendable (any LibraryPersistence) async -> Void) {
    let previous = saveChain
    let persistence = persistence
    saveChain = Task {
      await previous?.value
      await work(persistence)
    }
  }

  private static func sortedByRecency<Item: RecencySortable>(_ items: [Item]) -> [Item] {
    items.sorted { $0.updatedAt > $1.updatedAt }
  }
}

protocol RecencySortable {
  var updatedAt: Date { get }
}

extension Template: RecencySortable {}
extension Sheet: RecencySortable {}
