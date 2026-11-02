import Domain
import Foundation
import Testing

@testable import CardSheetCreator

@MainActor @Suite struct DeletionPromptTests {
  private func undoable(_ undo: UndoManager, on model: LibraryModel, _ change: () -> Void) {
    model.undoManager = undo
    undo.beginUndoGrouping()
    change()
    undo.endUndoGrouping()
  }

  @Test func namesTheSingleItemToDelete() async throws {
    let (_, model, _) = try await TestLibrary.sheetWithOneImage()
    let template = try #require(model.templates.first)

    let prompt = try #require(model.deletionPrompt(for: [.template(template.id)]))

    #expect(prompt.title == "Supprimer « Carte standard » ?")
  }

  @Test func countsASeveralItemSelection() async throws {
    let (_, model, sheet) = try await TestLibrary.sheetWithOneImage()
    let template = try #require(model.templates.first)

    let prompt = try #require(model.deletionPrompt(for: [.template(template.id), .sheet(sheet.id)]))

    #expect(prompt.title == "Supprimer 2 éléments ?")
  }

  @Test func warnsThatSheetsOfADeletedTemplateAreKept() async throws {
    let (_, model, sheet) = try await TestLibrary.sheetWithOneImage()
    let template = try #require(model.templates.first)

    let templatePrompt = try #require(model.deletionPrompt(for: [.template(template.id)]))
    let sheetPrompt = try #require(model.deletionPrompt(for: [.sheet(sheet.id)]))

    #expect(templatePrompt.message.contains("planches"))
    #expect(!sheetPrompt.message.contains("planches"))
  }

  @Test func asksNothingForAnEmptySelection() async throws {
    let (_, model, _) = try await TestLibrary.sheetWithOneImage()

    #expect(model.deletionPrompt(for: []) == nil)
  }

  @Test func confirmingDeletesOnlyItemsStillInTheLibrary() async throws {
    let (_, model, sheet) = try await TestLibrary.sheetWithOneImage()
    let template = try #require(model.templates.first)
    let prompt = try #require(model.deletionPrompt(for: [.template(template.id), .sheet(sheet.id)]))
    model.delete([.sheet(sheet.id)])

    model.confirmDeletion(prompt)

    #expect(model.templates.isEmpty)
    #expect(model.sheets.isEmpty)
  }

  @Test func confirmingWhenNothingIsLeftRecordsNoUndo() async throws {
    let (_, model, sheet) = try await TestLibrary.sheetWithOneImage()
    let prompt = try #require(model.deletionPrompt(for: [.sheet(sheet.id)]))
    model.delete([.sheet(sheet.id)])
    let undo = UndoManager()

    undoable(undo, on: model) { model.confirmDeletion(prompt) }

    #expect(undo.undoActionName.isEmpty)
  }

  @Test func deletingATemplateKeepsTheSheetsMadeFromIt() async throws {
    let (_, model, sheet) = try await TestLibrary.sheetWithOneImage()
    let template = try #require(model.templates.first)

    model.confirmDeletion(try #require(model.deletionPrompt(for: [.template(template.id)])))

    #expect(model.templates.isEmpty)
    #expect(model.sheets.map(\.id) == [sheet.id])
  }
}
