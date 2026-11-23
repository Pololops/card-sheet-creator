import Foundation

// Why: see docs/adr/0004-json-library-persistence.md (the library lives in Application Support/CardSheetCreator/Library/)
// and docs/adr/0013-confirm-every-deletion.md (an interim library is renamed, never deleted).
extension FileLibraryStore {
  private static let adoptionMarkerName = ".adopted"
  private static let manifestName = "manifest.json"

  /// Where the sandboxed releases kept the library, before the app left the App Sandbox.
  public static func sandboxedRoot(bundleIdentifier: String, home: URL) -> URL {
    home
      .appendingPathComponent("Library/Containers/\(bundleIdentifier)/Data", isDirectory: true)
      .appendingPathComponent("Library/Application Support/CardSheetCreator/Library", isDirectory: true)
  }

  /// Copies the sandbox container's library to `target`, once. The container is only ever read: the
  /// previous version may still be launched and keeps working on it.
  ///
  /// The marker is written last, so any failure leaves the adoption to be retried at the next launch.
  /// The copy lands in a temporary sibling first so that the interim library, created by an earlier
  /// failed attempt, is only set aside once there is something to replace it with.
  public static func adoptSandboxedLibrary(from source: URL, into target: URL) throws {
    let fileManager = FileManager.default
    let supportFolder = target.deletingLastPathComponent()
    let marker = supportFolder.appendingPathComponent(adoptionMarkerName)
    guard !fileManager.fileExists(atPath: marker.path) else { return }
    try fileManager.createDirectory(at: supportFolder, withIntermediateDirectories: true)

    if try hasLibrary(at: source) {
      try replaceTarget(with: source, in: supportFolder, target: target)
    }
    try Data().write(to: marker, options: .atomic)
  }

  /// Only a provably missing manifest means "nothing to adopt". A denied read (EPERM from macOS
  /// App Data protection, EACCES) looks the same to `fileExists`, and the marker would then
  /// give up on a library that is still there, for good.
  private static func hasLibrary(at source: URL) throws -> Bool {
    do {
      return try source.appendingPathComponent(manifestName).checkResourceIsReachable()
    } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
      return false
    }
  }

  private static func replaceTarget(with source: URL, in supportFolder: URL, target: URL) throws {
    let fileManager = FileManager.default
    let staging = supportFolder.appendingPathComponent("Library.adopting-\(UUID().uuidString)")
    var setAsideInterim: URL?
    do {
      try fileManager.copyItem(at: source, to: staging)
      if fileManager.fileExists(atPath: target.path) {
        let datedName = unusedDatedName(for: target)
        try fileManager.moveItem(at: target, to: datedName)
        setAsideInterim = datedName
      }
      try fileManager.moveItem(at: staging, to: target)
    } catch {
      try? fileManager.removeItem(at: staging)
      restoreInterim(setAsideInterim, to: target)
      throw error
    }
  }

  /// A failure between the two renames would leave no `Library` at all, and the app would start
  /// on an empty one while the interim work sits hidden under a dated name.
  private static func restoreInterim(_ setAside: URL?, to target: URL) {
    let fileManager = FileManager.default
    guard let setAside, !fileManager.fileExists(atPath: target.path) else { return }
    // Best effort on purpose: the caller rethrows the original error, and should this restore fail too,
    // the interim library stays under its dated name, nothing deleted.
    try? fileManager.moveItem(at: setAside, to: target)
  }

  /// `Library-<yyyyMMdd-HHmmss>`; a taken name moves on to the next second rather than overwriting.
  private static func unusedDatedName(for target: URL) -> URL {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    var moment = Date()
    var candidate = datedSibling(of: target, formatter.string(from: moment))
    while FileManager.default.fileExists(atPath: candidate.path) {
      moment.addTimeInterval(1)
      candidate = datedSibling(of: target, formatter.string(from: moment))
    }
    return candidate
  }

  private static func datedSibling(of target: URL, _ stamp: String) -> URL {
    target.deletingLastPathComponent().appendingPathComponent("\(target.lastPathComponent)-\(stamp)")
  }
}
