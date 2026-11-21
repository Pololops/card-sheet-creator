import AppKit
import Domain
import Foundation
import Storage

struct StagedUpdate: Equatable {
  let app: URL
  let staging: URL
}

/// The boundaries a test swaps: the session configuration, the installed app and its version, the trusted key,
/// the result file, and the install policy (where an install is allowed, how the relaunch happens).
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
  /// How long the helper waits for the app to finish quitting (library flush included) before giving up.
  private static let quitTimeoutSeconds = 30
  private static let opener = URL(filePath: "/usr/bin/open")
  /// Beside the library, in the app's own support folder. Where that folder cannot be made, the library runs
  /// on a throwaway one too (see `AppEnvironment`): the result then goes to the temporary directory.
  private static let resultFile = supportDirectory.appending(path: "update-result")
  private static let supportDirectory =
    (try? FileLibraryStore.defaultRoot())?.deletingLastPathComponent()
    ?? FileManager.default.temporaryDirectory

  static func live() -> UpdateContext {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = requestTimeoutSeconds
    let versionText = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    let version = versionText.flatMap(SemanticVersion.init)
    let installedApp = Bundle.main.bundleURL
    return UpdateContext(
      configuration: configuration,
      installedApp: installedApp,
      installedVersion: version ?? SemanticVersion(major: 0, minor: 0, patch: 0),
      trustedKey: UpdateVerification.embeddedPublicKey,
      resultFile: resultFile,
      canInstall: canInstallHere,
      launchInstall: { try launchInstall($0, replacing: installedApp) })
  }

  /// A debug build runs from the build folder: replacing it would swap the developer's own build.
  private static func canInstallHere(_ app: URL) -> Bool {
    #if DEBUG
      false
    #else
      UpdateInstaller.canReplace(appAt: app)
    #endif
  }

  /// Quits through the normal path so the library is flushed; the helper takes over once this process is gone.
  private static func launchInstall(_ staged: StagedUpdate, replacing installedApp: URL) throws {
    let job = HelperJob(
      processID: ProcessInfo.processInfo.processIdentifier, app: installedApp, staged: staged.app,
      staging: staged.staging, resultFile: resultFile, opener: opener, timeoutSeconds: quitTimeoutSeconds)
    try UpdateInstaller.launchHelper(job)
    NSApplication.shared.terminate(nil)
  }
}
