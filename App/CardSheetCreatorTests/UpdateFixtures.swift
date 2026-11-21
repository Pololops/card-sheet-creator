import CryptoKit
import Domain
import Foundation
import Testing

@testable import CardSheetCreator

enum FixtureError: Error {
  case dittoFailed(Int32)
  case invalidURL(String)
}

enum UpdateFixtures {
  nonisolated static let bundleIdentifier = "com.pololops.CardSheetCreator"
  private static let versionKey = "CFBundleShortVersionString"

  static func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// A minimal bundle: the updater only ever reads its `Info.plist`.
  @discardableResult
  static func makeApp(
    in directory: URL, bundleIdentifier: String = bundleIdentifier, version: String
  ) throws -> URL {
    let app = directory.appending(path: "CardSheetCreator.app")
    let contents = app.appending(path: "Contents")
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    let info = ["CFBundleIdentifier": bundleIdentifier, versionKey: version]
    let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    try plist.write(to: contents.appending(path: "Info.plist"))
    return app
  }

  static func bundleVersion(of app: URL) throws -> String? {
    let plist = try Data(contentsOf: app.appending(path: "Contents/Info.plist"))
    let info = try PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any]
    return info?[versionKey] as? String
  }

  /// Zips like `release.sh` does, with the real `ditto`.
  static func archive(of app: URL, to zip: URL) throws {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/ditto")
    process.arguments = ["-c", "-k", "--keepParent", app.path, zip.path]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw FixtureError.dittoFailed(process.terminationStatus) }
  }

  /// Polls a condition that another task makes true; the test fails on the deadline, never hangs.
  static func eventually(timeout: Duration = .seconds(5), _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
      if condition() { return true }
      try? await Task.sleep(for: .milliseconds(20))
    }
    return condition()
  }
}

extension UpdateController.Phase {
  var offeredVersion: SemanticVersion? {
    guard case .available(let update) = self else { return nil }
    return update.version
  }

  var hasStartedDownloading: Bool {
    guard case .downloading(let received, _) = self else { return false }
    return received > 0
  }
}

struct LaunchRefused: Error {}

/// A fake GitHub plus a fake installed app: what an `UpdateController` needs to run for real.
@MainActor
final class UpdateRig {
  static let defaultDownloads = "https://github.com/Pololops/card-sheet-creator/releases/download"
  static let partialDownloadSize = 5_000

  let installedApp: URL
  let resultFile: URL
  private(set) var archive = Data()
  private(set) var archiveURL = URL(filePath: "/")
  private(set) var signatureURL = URL(filePath: "/")
  private(set) var launchAttempts: [StagedUpdate] = []
  var launchFailure: (any Error)?
  private let directory: URL
  private let stagingRoot: URL
  private let trustedKey = Curve25519.Signing.PrivateKey()

  init() throws {
    let directory = try UpdateFixtures.temporaryDirectory()
    let app = try UpdateFixtures.makeApp(in: directory.appending(path: "Applications"), version: "0.6.0")
    self.directory = directory
    installedApp = app
    resultFile = directory.appending(path: "Support/update-result")
    stagingRoot = try Self.locateStagingRoot(appropriateFor: app)
    StubURLProtocol.serve([:])
  }

  /// The system folder that holds every staging folder. It cannot be listed, only counted.
  private static func locateStagingRoot(appropriateFor app: URL) throws -> URL {
    let probe = try FileManager.default.url(
      for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: app, create: true)
    try FileManager.default.removeItem(at: probe)
    return probe.deletingLastPathComponent()
  }

  var requestedURLs: [URL] { StubURLProtocol.requestedURLs }

  /// Publishes a release whose archive holds an app with the given identity, signed by `signer`
  /// (the key the controller trusts when `nil`).
  func publish(
    tag: String = "v0.7.0", bundleVersion: String = "0.7.0",
    bundleIdentifier: String = UpdateFixtures.bundleIdentifier,
    signedBy signer: Curve25519.Signing.PrivateKey? = nil, declaredSize: Int? = nil,
    downloadsBase: String = defaultDownloads
  ) throws {
    let workspace = directory.appending(path: UUID().uuidString)
    let app = try UpdateFixtures.makeApp(
      in: workspace, bundleIdentifier: bundleIdentifier, version: bundleVersion)
    let zip = workspace.appending(path: "CardSheetCreator.zip")
    try UpdateFixtures.archive(of: app, to: zip)
    archive = try Data(contentsOf: zip)
    let signature = try (signer ?? trustedKey).signature(for: archive)
    archiveURL = try url("\(downloadsBase)/\(tag)/CardSheetCreator.zip")
    signatureURL = try url("\(downloadsBase)/\(tag)/CardSheetCreator.zip.sig")
    let assets = [
      asset("CardSheetCreator.zip", at: archiveURL, size: declaredSize ?? archive.count),
      asset("CardSheetCreator.zip.sig", at: signatureURL, size: signature.count),
    ]
    let release = try JSONSerialization.data(withJSONObject: ["tag_name": tag, "assets": assets])
    StubURLProtocol.serve([
      LatestRelease.endpoint: StubResponse(body: release),
      archiveURL: StubResponse(body: archive),
      signatureURL: StubResponse(body: signature),
    ])
  }

  func serve(_ response: StubResponse, at url: URL) {
    StubURLProtocol.serve(response, at: url)
  }

  /// Swaps the published archive for other bytes, signed like a genuine one.
  func replaceArchive(with bytes: Data, signedBy signer: Curve25519.Signing.PrivateKey? = nil) throws {
    archive = bytes
    serve(StubResponse(body: bytes), at: archiveURL)
    serve(StubResponse(body: try (signer ?? trustedKey).signature(for: bytes)), at: signatureURL)
  }

  /// How many staging folders exist: each one adds a link to the folder that holds them.
  var stagingFolderCount: Int {
    let attributes = try? FileManager.default.attributesOfItem(atPath: stagingRoot.path)
    return (attributes?[.referenceCount] as? Int) ?? 0
  }

  /// Half-written downloads in the temporary folder, recognised by the size of what the rig serves.
  var partialDownloads: Set<String> {
    let folder = FileManager.default.temporaryDirectory
    let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
    return Set(
      names.filter { name in
        let path = folder.appending(path: name).path
        let size = try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int
        return name.hasPrefix("CFNetworkDownload") && size == Self.partialDownloadSize
      })
  }

  /// What a helper that failed the swap leaves for the next launch.
  func leaveFailedSwapResult() throws {
    try FileManager.default.createDirectory(
      at: resultFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("failed\n".utf8).write(to: resultFile)
  }

  /// A controller for the installed 0.6.0 app, trusting the rig's key.
  func makeController(canInstall: Bool = true) -> UpdateController {
    UpdateController(
      context: UpdateContext(
        configuration: StubURLProtocol.configuration, installedApp: installedApp,
        installedVersion: SemanticVersion(major: 0, minor: 6, patch: 0),
        trustedKey: trustedKey.publicKey.rawRepresentation,
        resultFile: resultFile, canInstall: { _ in canInstall },
        launchInstall: { [self] staged in
          launchAttempts.append(staged)
          if let launchFailure { throw launchFailure }
        }))
  }

  private func asset(_ name: String, at url: URL, size: Int) -> [String: Any] {
    ["name": name, "browser_download_url": url.absoluteString, "size": size]
  }

  private func url(_ string: String) throws -> URL {
    guard let url = URL(string: string) else { throw FixtureError.invalidURL(string) }
    return url
  }

  /// A controller that has found the 0.7.0 release at launch; the archive may be made unfit to install.
  func offeredController(
    bundleVersion: String = "0.7.0", bundleIdentifier: String = UpdateFixtures.bundleIdentifier,
    signedBy signer: Curve25519.Signing.PrivateKey? = nil, declaredSize: Int? = nil,
    canInstall: Bool = true
  ) async throws -> UpdateController {
    try publish(
      bundleVersion: bundleVersion, bundleIdentifier: bundleIdentifier, signedBy: signer,
      declaredSize: declaredSize)
    let controller = makeController(canInstall: canInstall)
    await controller.checkAtLaunch()
    try #require(controller.phase?.offeredVersion != nil)
    return controller
  }

  /// Starts an install whose download never completes, once it has reported some progress.
  func downloadInProgress() async throws -> (UpdateController, Task<Void, Never>) {
    let controller = try await offeredController(declaredSize: 10_000)
    serve(StubResponse(body: Data(count: Self.partialDownloadSize), staysOpen: true), at: archiveURL)
    let install = Task { await controller.install() }
    let started = await UpdateFixtures.eventually { controller.phase?.hasStartedDownloading == true }
    try #require(started, "the download never reported progress")
    return (controller, install)
  }
}
