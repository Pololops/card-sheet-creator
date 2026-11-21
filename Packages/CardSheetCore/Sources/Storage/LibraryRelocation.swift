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

    let hasContainerLibrary = fileManager.fileExists(
      atPath: source.appendingPathComponent(manifestName).path)
    if hasContainerLibrary {
      try replaceTarget(with: source, in: supportFolder, target: target)
    }
    try Data().write(to: marker, options: .atomic)
  }

  private static func replaceTarget(with source: URL, in supportFolder: URL, target: URL) throws {
    let fileManager = FileManager.default
    let staging = supportFolder.appendingPathComponent("Library.adopting-\(UUID().uuidString)")
    do {
      try fileManager.copyItem(at: source, to: staging)
      if fileManager.fileExists(atPath: target.path) {
        try fileManager.moveItem(at: target, to: unusedDatedName(for: target))
      }
      try fileManager.moveItem(at: staging, to: target)
    } catch {
      try? fileManager.removeItem(at: staging)
      throw error
    }
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
