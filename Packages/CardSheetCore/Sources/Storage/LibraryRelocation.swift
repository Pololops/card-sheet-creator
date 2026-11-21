import Foundation

extension FileLibraryStore {
  public static func sandboxedRoot(bundleIdentifier: String, home: URL) -> URL {
    home
  }

  public static func adoptSandboxedLibrary(from source: URL, into target: URL) throws {
    throw NotImplemented()
  }
}
