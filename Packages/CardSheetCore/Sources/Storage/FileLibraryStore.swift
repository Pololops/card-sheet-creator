import Domain
import Foundation

/// JSON files plus an image folder. Changes are coalesced and written atomically after a short pause.
public actor FileLibraryStore: LibraryPersistence {
  public static let defaultDebounce = Duration.milliseconds(400)

  private enum Folder {
    static let templates = "templates"
    static let sheets = "sheets"
    static let images = "images"
  }

  private static let manifestFile = "manifest.json"
  private static let settingsFile = "settings.json"

  private let root: URL
  private let debounce: Duration
  private let onSaveError: @Sendable (Error) -> Void
  private let migrator = Migrator.library
  /// Relative path → bytes to write, or `nil` to delete.
  private var pending: [String: Data?] = [:]
  private var scheduledWrite: Task<Void, Never>?

  public init(
    root: URL, debounce: Duration = FileLibraryStore.defaultDebounce,
    onSaveError: @escaping @Sendable (Error) -> Void = { _ in }
  ) {
    self.root = root
    self.debounce = debounce
    self.onSaveError = onSaveError
  }

  public static func defaultRoot() throws -> URL {
    try FileManager.default
      .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      .appendingPathComponent("CardSheetCreator/Library", isDirectory: true)
  }

  public func loadAll() throws -> LibrarySnapshot {
    if let manifest = try? Data(contentsOf: url(Self.manifestFile)),
      let object = try? JSONSerialization.jsonObject(with: manifest) as? [String: Any],
      let version = object["schemaVersion"] as? Int, version > migrator.currentVersion
    {
      throw StorageError.newerSchema(found: version)
    }
    let settings: PrintSettings? = try read(Self.settingsFile)
    return LibrarySnapshot(
      templates: try readAll(Folder.templates), sheets: try readAll(Folder.sheets),
      printSettings: settings ?? PrintSettings())
  }

  public func save(_ template: Template) {
    enqueue(template, at: "\(Folder.templates)/\(template.id.uuidString).json")
  }

  public func save(_ sheet: Sheet) {
    enqueue(sheet, at: "\(Folder.sheets)/\(sheet.id.uuidString).json")
  }

  public func save(_ settings: PrintSettings) {
    enqueue(settings, at: Self.settingsFile)
  }

  public func deleteTemplate(id: UUID) {
    schedule("\(Folder.templates)/\(id.uuidString).json", data: nil)
  }

  public func deleteSheet(id: UUID) {
    schedule("\(Folder.sheets)/\(id.uuidString).json", data: nil)
  }

  public func importImages(at urls: [URL]) -> ImportReport {
    ImageImporter(directory: url(Folder.images)).importImages(at: urls)
  }

  public nonisolated func imageURL(for image: ImageRef) -> URL {
    root.appendingPathComponent(Folder.images).appendingPathComponent(image.fileName)
  }

  public func flush() throws {
    scheduledWrite?.cancel()
    scheduledWrite = nil
    try writePending()
  }

  public func purgeImages(notIn hashes: Set<String>) throws {
    let folder = url(Folder.images)
    guard FileManager.default.fileExists(atPath: folder.path) else { return }
    for file in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
    where !hashes.contains(file.deletingPathExtension().lastPathComponent) {
      try FileManager.default.removeItem(at: file)
    }
  }

  private func enqueue(_ value: some Encodable, at path: String) {
    do {
      schedule(
        path, data: try Self.encoder.encode(Envelope(schemaVersion: migrator.currentVersion, payload: value)))
    } catch {
      onSaveError(error)
    }
  }

  private func schedule(_ path: String, data: Data?) {
    pending[path] = .some(data)
    scheduledWrite?.cancel()
    scheduledWrite = Task { [debounce] in
      try? await Task.sleep(for: debounce)
      guard !Task.isCancelled else { return }
      do {
        try writePending()
      } catch {
        onSaveError(error)
      }
    }
  }

  private func writePending() throws {
    try writeManifestIfNeeded()
    var firstError: Error?
    for (path, data) in pending {
      do {
        let target = url(path)
        if let data {
          try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
          try data.write(to: target, options: .atomic)
        } else if FileManager.default.fileExists(atPath: target.path) {
          try FileManager.default.removeItem(at: target)
        }
        pending[path] = nil
      } catch {
        firstError = firstError ?? error
      }
    }
    if let firstError { throw firstError }
  }

  private func writeManifestIfNeeded() throws {
    let manifest = url(Self.manifestFile)
    guard !FileManager.default.fileExists(atPath: manifest.path) else { return }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Self.encoder.encode(["schemaVersion": migrator.currentVersion]).write(to: manifest, options: .atomic)
  }

  private func readAll<Value: Decodable>(_ folder: String) throws -> [Value] {
    let directory = url(folder)
    guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
    return try FileManager.default.contentsOfDirectory(atPath: directory.path)
      .filter { $0.hasSuffix(".json") }
      .sorted()
      .compactMap { try read("\(folder)/\($0)") }
  }

  private func read<Value: Decodable>(_ path: String) throws -> Value? {
    guard let data = try? Data(contentsOf: url(path)) else { return nil }
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let version = object["schemaVersion"] as? Int, let payload = object["payload"] as? [String: Any]
    else { throw StorageError.corruptFile(path) }
    let migrated = try migrator.migrate(payload, from: version)
    do {
      return try Self.decoder.decode(Value.self, from: JSONSerialization.data(withJSONObject: migrated))
    } catch {
      throw StorageError.corruptFile(path)
    }
  }

  private func url(_ path: String) -> URL {
    root.appendingPathComponent(path)
  }

  private static var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  private static var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}

private struct Envelope<Payload: Encodable>: Encodable {
  let schemaVersion: Int
  let payload: Payload
}
