import Foundation
import Printing
import Storage

/// Composition root: the one place where concrete storage and printing are chosen.
@MainActor
final class AppEnvironment {
  let model: LibraryModel
  let images: ImageCache
  let printService: AppKitPrintService
  let persistence: FileLibraryStore

  init() {
    let (failures, continuation) = AsyncStream<String>.makeStream()
    persistence = FileLibraryStore(root: Self.libraryRoot) { error in
      continuation.yield(error.localizedDescription)
    }
    model = LibraryModel(persistence: persistence)
    images = ImageCache(persistence: persistence)
    printService = AppKitPrintService()

    let model = model
    Task {
      for await message in failures { model.saveFailure = message }
    }
  }

  /// Unit tests launch the app as their host: they get a throwaway library, never the user's.
  private static var libraryRoot: URL {
    let isTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    if !isTestHost, let root = try? FileLibraryStore.defaultRoot() { return root }
    return FileManager.default.temporaryDirectory.appendingPathComponent(
      "CardSheetCreator-\(UUID().uuidString)")
  }
}
