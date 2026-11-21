import Domain
import Foundation

struct StagedUpdate: Equatable {
  let app: URL
  let staging: URL
}

/// Everything the updater touches outside the process: network, disk, trust and the relaunch.
struct UpdateContext {
  var configuration: URLSessionConfiguration
  var installedApp: URL
  var installedVersion: SemanticVersion
  var trustedKey: Data
  var resultFile: URL
  var canInstall: (URL) -> Bool
  var launchInstall: (StagedUpdate) throws -> Void

  /// Idle time, not total: a slow download that keeps receiving bytes is not cut, a dead connection is.
  private static let requestTimeoutSeconds: TimeInterval = 30

  static func live() -> UpdateContext {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = requestTimeoutSeconds
    let versionText = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    let version = versionText.flatMap(SemanticVersion.init)
    return UpdateContext(
      configuration: configuration,
      installedApp: Bundle.main.bundleURL,
      installedVersion: version ?? SemanticVersion(major: 0, minor: 0, patch: 0),
      trustedKey: UpdateVerification.embeddedPublicKey,
      resultFile: URL.applicationSupportDirectory.appending(path: "CardSheetCreator/update-result"),
      canInstall: { _ in true },
      launchInstall: { _ in })
  }
}
