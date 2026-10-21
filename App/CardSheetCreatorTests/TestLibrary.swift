import Domain
import Foundation
import Storage
import Testing

@testable import CardSheetCreator

enum TestLibrary {
  /// A fresh library on disk holding one sheet made of a single gray image.
  @MainActor
  static func sheetWithOneImage() async throws
    -> (store: FileLibraryStore, model: LibraryModel, sheet: Sheet)
  {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let picked = base.appendingPathComponent("Contes du soir")
    try FileManager.default.createDirectory(at: picked, withIntermediateDirectories: true)
    let store = FileLibraryStore(root: base.appendingPathComponent("Library"), debounce: .seconds(60))
    let model = LibraryModel(persistence: store)
    await model.load()
    let template = try #require(model.templates.first)
    let image = try TestImages.png(at: picked.appendingPathComponent("carte.png"), gray: 0.5)
    let sheet = try #require(await model.createSheets(from: [image], template: template).first)
    return (store, model, sheet)
  }
}
