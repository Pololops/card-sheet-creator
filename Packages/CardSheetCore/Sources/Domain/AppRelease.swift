import Foundation

public struct LatestRelease: Decodable, Sendable {
  public struct Asset: Decodable, Sendable {
    public let name: String
    public let browserDownloadURL: URL
    public let size: Int

    private enum CodingKeys: String, CodingKey {
      case name, size
      case browserDownloadURL = "browser_download_url"
    }
  }

  public let tagName: String
  public let assets: [Asset]

  private enum CodingKeys: String, CodingKey {
    case assets
    case tagName = "tag_name"
  }

  public static let endpoint = URL(filePath: "/")
  public static let maximumArchiveSize = 0

  public func update(over installed: SemanticVersion) throws -> AvailableUpdate? {
    throw NotImplemented()
  }
}

public struct AvailableUpdate: Equatable, Sendable {
  public let version: SemanticVersion
  public let archive: URL
  public let archiveSize: Int
  public let signature: URL
}

public enum ReleaseError: Error, Equatable {
  case invalidTag
  case missingAsset
  case untrustedURL
  case tooLarge
}
