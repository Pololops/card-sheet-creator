import Foundation
import OSLog
import Observation
import Printing
import Storage

/// Composition root: the one place where concrete storage and printing are chosen.
@MainActor
@Observable
final class AppEnvironment {
  let model: LibraryModel
  let images: ImageCache
  let printService: AppKitPrintService
  let persistence: FileLibraryStore
  let calibrationRoute = ColorCalibrationRoute()
  let updates = UpdateController(context: .live())
  /// The previous version's library could not be copied: the app runs on an interim library until the next launch.
  /// Cleared once acknowledged, so that opening another window does not announce it again.
  var hasPendingRecoveryNotice: Bool

  private static let logger = Logger(subsystem: "com.pololops.CardSheetCreator", category: "library")

  init() {
    let (failures, continuation) = AsyncStream<String>.makeStream()
    let library = Self.prepareLibraryRoot()
    hasPendingRecoveryNotice = library.hasAdoptionFailed
    persistence = FileLibraryStore(root: library.root) { error in
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
  /// A real launch first adopts the library the sandboxed releases kept in their container.
  // Why: see docs/adr/0004-json-library-persistence.md (library under Application Support/CardSheetCreator/Library/).
  private static func prepareLibraryRoot() -> (root: URL, hasAdoptionFailed: Bool) {
    let isTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    guard !isTestHost, let root = try? FileLibraryStore.defaultRoot() else {
      let throwaway = FileManager.default.temporaryDirectory.appendingPathComponent(
        "CardSheetCreator-\(UUID().uuidString)")
      return (throwaway, false)
    }
    return (root, adoptSandboxedLibrary(into: root))
  }

  /// Returns whether adoption failed. A failure is not fatal: the app starts on an interim library and retries
  /// at the next launch.
  private static func adoptSandboxedLibrary(into root: URL) -> Bool {
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return false }
    let container = FileLibraryStore.sandboxedRoot(bundleIdentifier: bundleIdentifier, home: .homeDirectory)
    do {
      try FileLibraryStore.adoptSandboxedLibrary(from: container, into: root)
      return false
    } catch {
      logger.error("Library adoption failed: \(error.localizedDescription)")
      return true
    }
  }
}
