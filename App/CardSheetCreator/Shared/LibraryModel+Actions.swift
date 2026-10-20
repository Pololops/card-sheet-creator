import Domain
import Foundation
import Storage

struct ImportSummary: Equatable {
  var createdSheets: Int
  var skipped: [SkippedFile]
}

/// Shown after a sheet resize: offers to keep the new size as a blank template.
struct TemplateOffer: Equatable {
  var geometry: SheetGeometry
  var sheetName: String
  var overflowSheetName: String?
  var movedCount: Int

  var suggestedName: String {
    "Carte \(geometry.slot.width.formatted) × \(geometry.slot.height.formatted)"
  }
}

extension LibraryModel {
  // MARK: - Templates

  @discardableResult
  func createTemplate() -> Template {
    let template = Template(
      id: UUID(), name: "Nouveau gabarit", geometry: SheetGeometry(slot: .standardCard), createdAt: now(),
      updatedAt: now())
    change("Nouveau gabarit") { templates, _ in templates.append(template) }
    selection = [.template(template.id)]
    return template
  }

  func updateGeometry(ofTemplate id: UUID, to geometry: SheetGeometry) {
    guard (try? Domain.GridLayout.make(geometry)) != nil, template(id: id)?.geometry != geometry else {
      return
    }
    change("Modifier les dimensions") { templates, _ in
      guard let index = templates.firstIndex(where: { $0.id == id }) else { return }
      templates[index].geometry = geometry
      templates[index].updatedAt = now()
    }
  }

  func rename(_ item: LibraryItem, to name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    change("Renommer") { templates, sheets in
      switch item {
      case .template(let id):
        guard let index = templates.firstIndex(where: { $0.id == id }), templates[index].name != trimmed
        else { return }
        templates[index].name = trimmed
        templates[index].updatedAt = now()
      case .sheet(let id):
        guard let index = sheets.firstIndex(where: { $0.id == id }), sheets[index].name != trimmed else {
          return
        }
        sheets[index].name = trimmed
        sheets[index].updatedAt = now()
      }
    }
  }

  func duplicate(_ item: LibraryItem) {
    var copy: LibraryItem?
    change("Dupliquer") { templates, sheets in
      switch item {
      case .template(let id):
        guard var template = templates.first(where: { $0.id == id }) else { return }
        template.id = UUID()
        template.name += " copie"
        template.createdAt = now()
        template.updatedAt = now()
        templates.append(template)
        copy = .template(template.id)
      case .sheet(let id):
        guard var sheet = sheets.first(where: { $0.id == id }) else { return }
        sheet.id = UUID()
        sheet.name += " copie"
        sheet.createdAt = now()
        sheet.updatedAt = now()
        sheets.append(sheet)
        copy = .sheet(sheet.id)
      }
    }
    if let copy { selection = [copy] }
  }

  /// Immediate, with ⌘Z to bring items back; their images stay on disk until the next launch.
  func delete(_ items: Set<LibraryItem>) {
    guard !items.isEmpty else { return }
    change(items.count == 1 ? "Supprimer" : "Supprimer \(items.count) éléments") { templates, sheets in
      templates.removeAll { items.contains(.template($0.id)) }
      sheets.removeAll { items.contains(.sheet($0.id)) }
    }
    selection.subtract(items)
  }

  // MARK: - Sheets

  @discardableResult
  func createSheets(from urls: [URL], template: Template) async -> [Sheet] {
    let report = await persistence.importImages(at: urls)
    let folder = urls.first?.deletingLastPathComponent().lastPathComponent
    let baseName = SheetNaming.baseName(fileNames: report.imported.map(\.originalName), folderName: folder)
    let created =
      (try? Distribution.sheets(
        for: report.imported, from: template, baseName: baseName, now: now(), makeID: UUID.init)) ?? []
    if !created.isEmpty {
      change(created.count == 1 ? "Nouvelle planche" : "Nouvelles planches") { _, sheets in
        sheets.append(contentsOf: created)
      }
      selection = [.sheet(created[0].id)]
    }
    importSummary = ImportSummary(createdSheets: created.count, skipped: report.skipped)
    return created
  }

  /// Keyed by image, so every clone on the sheet takes the same framing.
  func setCrop(_ anchor: CropAnchor, for image: ImageRef, inSheet id: UUID) {
    guard sheet(id: id)?.crop(for: image) != anchor else { return }
    change("Cadrage") { _, sheets in
      guard let index = sheets.firstIndex(where: { $0.id == id }) else { return }
      sheets[index].setCrop(anchor, for: image)
      sheets[index].updatedAt = now()
    }
  }

  @discardableResult
  func applyResize(_ draft: ResizeDraft) throws -> ResizeOutcome {
    let outcome = try draft.sheet.resized(to: draft.geometry, now: now(), makeID: UUID.init)
    change("Modifier les dimensions") { _, sheets in
      guard let index = sheets.firstIndex(where: { $0.id == draft.sheet.id }) else { return }
      sheets[index] = outcome.sheet
      sheets.append(contentsOf: outcome.overflow)
    }
    pendingTemplateOffer = TemplateOffer(
      geometry: draft.geometry, sheetName: outcome.sheet.name,
      overflowSheetName: outcome.overflow.first?.name,
      movedCount: outcome.movedCount)
    return outcome
  }

  func acceptTemplateOffer(named name: String) {
    guard let offer = pendingTemplateOffer else { return }
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let template = Template(
      id: UUID(), name: trimmed.isEmpty ? offer.suggestedName : trimmed, geometry: offer.geometry,
      createdAt: now(), updatedAt: now())
    change("Nouveau gabarit") { templates, _ in templates.append(template) }
    pendingTemplateOffer = nil
  }

  func declineTemplateOffer() {
    pendingTemplateOffer = nil
  }

}

extension Millimeters {
  /// French decimal formatting without a trailing ",0" on whole millimetres: "54", "85,6".
  var formatted: String {
    tenths % 10 == 0 ? "\(tenths / 10)" : "\(tenths / 10),\(abs(tenths % 10))"
  }
}
