import Domain
import Foundation
import Storage
import Testing

@testable import CardSheetCreator

@MainActor @Suite struct GeometryPreviewTests {
  private static let actionName = "Modifier les dimensions"

  private func geometry(width: Int) -> SheetGeometry {
    SheetGeometry(slot: SlotSize(width: .init(tenths: width), height: .init(tenths: 856)))
  }

  private func makeModel() async throws -> (store: FileLibraryStore, model: LibraryModel, template: Template)
  {
    let (store, model, _) = try await TestLibrary.sheetWithOneImage()
    return (store, model, try #require(model.templates.first))
  }

  private func makeUndo() -> UndoManager {
    let undo = UndoManager()
    undo.groupsByEvent = false
    return undo
  }

  private func undoable(_ undo: UndoManager, on model: LibraryModel, _ change: () -> Void) {
    model.undoManager = undo
    undo.beginUndoGrouping()
    change()
    undo.endUndoGrouping()
  }

  @Test func aPreviewIsShownButNotSaved() async throws {
    let (store, model, template) = try await makeModel()

    model.beginGeometryPreview(ofTemplate: template.id)
    model.previewGeometry(ofTemplate: template.id, to: geometry(width: 600))
    try await model.flush()

    #expect(model.geometry(ofTemplate: template.id) == geometry(width: 600))
    #expect(model.template(id: template.id)?.geometry == template.geometry)
    #expect(try await store.loadAll().templates.first?.geometry == template.geometry)
  }

  @Test func aPreviewRecordsNoUndo() async throws {
    let (_, model, template) = try await makeModel()
    let undo = makeUndo()

    undoable(undo, on: model) {
      model.beginGeometryPreview(ofTemplate: template.id)
      model.previewGeometry(ofTemplate: template.id, to: geometry(width: 600))
    }

    #expect(undo.undoActionName.isEmpty)
  }

  @Test func committingAPreviewIsOneUndoStep() async throws {
    let (_, model, template) = try await makeModel()
    let undo = makeUndo()
    model.beginGeometryPreview(ofTemplate: template.id)
    model.previewGeometry(ofTemplate: template.id, to: geometry(width: 600))

    undoable(undo, on: model) { model.commitGeometryPreview() }

    #expect(model.template(id: template.id)?.geometry == geometry(width: 600))
    #expect(undo.undoActionName == Self.actionName)
    undo.undo()
    #expect(model.template(id: template.id)?.geometry == template.geometry)
    #expect(!undo.canUndo)
  }

  @Test func discardingAPreviewKeepsTheSavedGeometry() async throws {
    let (_, model, template) = try await makeModel()
    model.beginGeometryPreview(ofTemplate: template.id)
    model.previewGeometry(ofTemplate: template.id, to: geometry(width: 600))

    model.discardGeometryPreview()

    #expect(model.geometryPreview == nil)
    #expect(model.geometry(ofTemplate: template.id) == template.geometry)
  }

  @Test func aPreviewBelongsToOneTemplate() async throws {
    let (_, model, template) = try await makeModel()
    let other = model.createTemplate()
    model.beginGeometryPreview(ofTemplate: template.id)

    model.previewGeometry(ofTemplate: other.id, to: geometry(width: 600))

    #expect(model.geometry(ofTemplate: other.id) == other.geometry)
    #expect(model.geometry(ofTemplate: template.id) == template.geometry)
  }

  @Test func aStepDuringAnActivePreviewStaysInThePreview() async throws {
    let (_, model, template) = try await makeModel()
    let undo = makeUndo()
    model.beginGeometryPreview(ofTemplate: template.id)

    undoable(undo, on: model) { model.editGeometry(ofTemplate: template.id, to: geometry(width: 600)) }

    #expect(undo.undoActionName.isEmpty)
    #expect(model.template(id: template.id)?.geometry == template.geometry)
    #expect(model.geometry(ofTemplate: template.id) == geometry(width: 600))
  }

  @Test func oneCommitHoldsEveryPreviewedStep() async throws {
    let (_, model, template) = try await makeModel()
    let undo = makeUndo()
    model.beginGeometryPreview(ofTemplate: template.id)
    for width in [600, 650, 700] {
      model.editGeometry(ofTemplate: template.id, to: geometry(width: width))
    }

    undoable(undo, on: model) { model.commitGeometryPreview() }

    #expect(model.template(id: template.id)?.geometry == geometry(width: 700))
    undo.undo()
    #expect(model.template(id: template.id)?.geometry == template.geometry)
    #expect(!undo.canUndo)
  }

  @Test func anEditWithoutAPreviewIsSavedAtOnce() async throws {
    let (_, model, template) = try await makeModel()
    let undo = makeUndo()

    undoable(undo, on: model) { model.editGeometry(ofTemplate: template.id, to: geometry(width: 600)) }

    #expect(model.template(id: template.id)?.geometry == geometry(width: 600))
    #expect(undo.undoActionName == Self.actionName)
  }

  @Test func undoDiscardsTheGeometryPreview() async throws {
    let (_, model, template) = try await makeModel()
    let undo = makeUndo()
    undoable(undo, on: model) { model.editGeometry(ofTemplate: template.id, to: geometry(width: 600)) }
    model.beginGeometryPreview(ofTemplate: template.id)
    model.previewGeometry(ofTemplate: template.id, to: geometry(width: 700))

    undo.undo()

    #expect(model.geometryPreview == nil)
    #expect(model.geometry(ofTemplate: template.id) == template.geometry)
  }

  @Test func committingAPreviewOfADeletedTemplateRecordsNoUndo() async throws {
    let (_, model, template) = try await makeModel()
    let undo = makeUndo()
    model.beginGeometryPreview(ofTemplate: template.id)
    model.previewGeometry(ofTemplate: template.id, to: geometry(width: 600))
    model.delete([.template(template.id)])

    undoable(undo, on: model) { model.commitGeometryPreview() }

    #expect(undo.undoActionName.isEmpty)
    #expect(model.template(id: template.id) == nil)
  }

  @Test func previewingAfterUndoChangesNothing() async throws {
    let (_, model, template) = try await makeModel()
    let undo = makeUndo()
    undoable(undo, on: model) { model.editGeometry(ofTemplate: template.id, to: geometry(width: 600)) }
    model.beginGeometryPreview(ofTemplate: template.id)
    undo.undo()

    model.previewGeometry(ofTemplate: template.id, to: geometry(width: 700))

    #expect(model.geometryPreview == nil)
    #expect(model.geometry(ofTemplate: template.id) == template.geometry)
  }
}
