import Foundation

// Why: see docs/adr/0003-feature-folders-and-local-package.md (one package, Foundation-only Domain target).
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

  /// The literal cannot fail to parse and a test pins its exact value, so the fallback only
  /// exists to keep this free of a force unwrap.
  public static let endpoint =
    URL(string: "https://api.github.com/repos/Pololops/card-sheet-creator/releases/latest")
    ?? URL(filePath: "/")
  /// Bounds what a release may ask the app to download and unpack; the real archive is ~20 MB.
  public static let maximumArchiveSize = 200_000_000
  /// An Ed25519 signature is always 64 bytes: any other size is not a signature, and is never fetched.
  private static let signatureSize = 64

  private static let archiveName = "CardSheetCreator.zip"
  private static let signatureName = "CardSheetCreator.zip.sig"
  private static let trustedHost = "github.com"
  private static let trustedPathPrefix = "/Pololops/card-sheet-creator/releases/download/"

  /// Strictly newer releases only: an equal or older one offers nothing, whatever its assets.
  public func update(over installed: SemanticVersion) throws -> AvailableUpdate? {
    guard let version = SemanticVersion(tagName) else { throw ReleaseError.invalidTag }
    guard version > installed else { return nil }
    let archive = try uniqueAsset(named: Self.archiveName)
    let signature = try uniqueAsset(named: Self.signatureName)
    guard Self.isTrusted(archive.browserDownloadURL), Self.isTrusted(signature.browserDownloadURL)
    else { throw ReleaseError.untrustedURL }
    guard (1...Self.maximumArchiveSize).contains(archive.size) else { throw ReleaseError.tooLarge }
    guard signature.size == Self.signatureSize else { throw ReleaseError.missingAsset }
    return AvailableUpdate(
      version: version, archive: archive.browserDownloadURL, archiveSize: archive.size,
      signature: signature.browserDownloadURL)
  }

  /// Two assets sharing a name are ambiguous: refusing beats guessing which one was published.
  private func uniqueAsset(named name: String) throws -> Asset {
    let matches = assets.filter { $0.name == name }
    guard matches.count == 1, let asset = matches.first else { throw ReleaseError.missingAsset }
    return asset
  }

  /// Pins a download to this project's release assets. The path is checked decoded so that
  /// `%2e%2e` cannot climb out of the prefix.
  private static func isTrusted(_ url: URL) -> Bool {
    guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
      parts.scheme == "https", parts.host?.lowercased() == trustedHost,
      parts.port == nil, parts.user == nil, parts.password == nil,
      parts.query == nil, parts.fragment == nil
    else { return false }
    let climbs = parts.path.split(separator: "/").contains("..")
    return parts.path.hasPrefix(trustedPathPrefix) && !climbs
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
