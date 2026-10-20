import Domain
import Foundation

public struct LibrarySnapshot: Equatable, Sendable {
  public var templates: [Template]
  public var sheets: [Sheet]
  public var printSettings: PrintSettings
}

public enum StorageError: Error, Equatable, Sendable {
  case newerSchema(found: Int)
  case corruptFile(String)
}

public enum SkipReason: Equatable, Sendable {
  case unreadable
  case unsupportedFormat
}

public struct SkippedFile: Equatable, Sendable {
  public var fileName: String
  public var reason: SkipReason
}

public struct ImportReport: Sendable {
  /// In selection order; the same content picked twice appears twice with an equal reference.
  public var imported: [ImageRef]
  public var skipped: [SkippedFile]
}

/// The app's only door to the disk, so feature code never touches files directly.
public protocol LibraryPersistence: Sendable {
  func loadAll() async throws -> LibrarySnapshot
  func save(_ template: Template) async
  func save(_ sheet: Sheet) async
  func save(_ settings: PrintSettings) async
  func deleteTemplate(id: UUID) async
  func deleteSheet(id: UUID) async
  func importImages(at urls: [URL]) async -> ImportReport
  nonisolated func imageURL(for image: ImageRef) -> URL
  /// Writes every pending change now; a failed write stays pending for the next attempt.
  func flush() async throws
  func purgeImages(notIn hashes: Set<String>) async throws
}
