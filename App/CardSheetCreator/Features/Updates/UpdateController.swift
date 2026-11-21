import AppKit
import Domain
import Foundation
import OSLog
import Observation

/// Drives the update sheet: checks for a release, then downloads, verifies and hands it over.
@Observable
final class UpdateController {
  enum Failure: Equatable {
    case network
    case notAuthentic
    case location
    case installFailed
  }

  enum Phase: Equatable {
    case upToDate
    case available(AvailableUpdate)
    case downloading(received: Int64, total: Int64)
    case installing
    case failed(Failure)
  }

  private struct UnexpectedStatus: Error {
    let code: Int?
  }

  private static let logger = Logger(subsystem: "com.pololops.CardSheetCreator", category: "updates")
  private static let successStatus = 200

  private(set) var phase: Phase?
  /// The sheet keeps showing the version on offer while it downloads and installs it.
  private(set) var offeredVersion: SemanticVersion?

  @ObservationIgnored private let context: UpdateContext
  @ObservationIgnored private var installation: Task<Void, any Error>?

  init(context: UpdateContext) {
    self.context = context
  }

  var installedVersion: SemanticVersion { context.installedVersion }

  var isBusy: Bool {
    switch phase {
    case .downloading, .installing: true
    case .upToDate, .available, .failed, nil: false
    }
  }

  /// Silent: only a failed swap or a newer release shows anything, every other outcome is logged at most.
  /// `isBusy` is tested again after the network await: an install may have started meanwhile, and the
  /// answer must not overwrite its progress.
  func checkAtLaunch() async {
    guard !isBusy else { return }
    if reportFailedSwap() { return }
    guard let update = await launchCheckUpdate(), !isBusy else { return }
    phase = .available(update)
  }

  /// The user asked, so unlike the launch check every outcome is answered, unless an install started meanwhile.
  func checkFromMenu() async {
    guard !isBusy else { return }
    let outcome = await menuCheckOutcome()
    guard !isBusy else { return }
    phase = outcome
  }

  private func launchCheckUpdate() async -> AvailableUpdate? {
    do {
      return try await latestUpdate()
    } catch {
      Self.logger.error("Launch update check failed: \(error.localizedDescription)")
      return nil
    }
  }

  private func menuCheckOutcome() async -> Phase {
    do {
      return try await latestUpdate().map(Phase.available) ?? .upToDate
    } catch {
      Self.logger.error("Menu update check failed: \(error.localizedDescription)")
      return .failed(.network)
    }
  }

  /// Ignored unless an update is on offer: a second tap while one install runs starts nothing.
  func install() async {
    guard case .available(let update) = phase else { return }
    guard context.canInstall(context.installedApp) else {
      phase = .failed(.location)
      return
    }
    offeredVersion = update.version
    phase = .downloading(received: 0, total: Int64(update.archiveSize))
    let installation = Task { try await stageAndLaunch(update) }
    self.installation = installation
    await conclude(installation, of: update)
  }

  func cancel() { installation?.cancel() }
  func dismiss() {
    guard !isBusy else { return }
    phase = nil
  }

  func revealApp() {
    NSWorkspace.shared.activateFileViewerSelecting([context.installedApp])
  }

  static func downloadLabel(received: Int64, total: Int64) -> String {
    let style = ByteCountFormatStyle(style: .file, locale: Locale(identifier: "fr_FR"))
    return "Téléchargement… \(received.formatted(style)) sur \(total.formatted(style))"
  }

  private func conclude(_ installation: Task<Void, any Error>, of update: AvailableUpdate) async {
    do {
      try await installation.value
    } catch is CancellationError {
      phase = .available(update)
    } catch is UpdateVerification.VerificationError, UpdateInstaller.InstallerError.appMissingFromArchive {
      Self.logger.error("Downloaded update refused: not authentic")
      phase = .failed(.notAuthentic)
    } catch {
      Self.logger.error("Update install failed: \(error.localizedDescription)")
      phase = .failed(.installFailed)
    }
    self.installation = nil
  }

  /// Nothing reaches `launchInstall` unless the signature held on the very archive that was unpacked and
  /// the unpacked bundle is the announced version of this app. Any throw removes what was staged.
  private func stageAndLaunch(_ update: AvailableUpdate) async throws {
    let staging = try UpdateInstaller.makeStagingDirectory(appropriateFor: context.installedApp)
    do {
      let app = try await downloadAndVerify(update, into: staging)
      try Task.checkCancellation()
      phase = .installing
      try context.launchInstall(StagedUpdate(app: app, staging: staging))
    } catch {
      removeStaging(staging)
      throw error
    }
  }

  private func downloadAndVerify(_ update: AvailableUpdate, into staging: URL) async throws -> URL {
    let archive = staging.appending(path: "CardSheetCreator.zip")
    let total = Int64(update.archiveSize)
    try await UpdateDownload.fetch(
      update.archive, to: archive, sizeLimit: update.archiveSize, configuration: context.configuration,
      onProgress: { received in Task { @MainActor in self.record(received: received, of: total) } })
    let signature = try await downloadSignature(update.signature, into: staging)
    try await UpdateVerification.verifySignature(
      archive: archive, signature: signature, publicKey: context.trustedKey)
    let app = try await UpdateInstaller.extract(archive: archive, into: staging)
    try await UpdateVerification.verifyStagedBundle(at: app, expectedVersion: update.version)
    return app
  }

  /// Fetched like the archive, so that a server cannot make the app hold more than a signature in memory.
  /// A file longer than a signature is no signature: that is an integrity failure, not a failed download.
  private func downloadSignature(_ url: URL, into staging: URL) async throws -> Data {
    let file = staging.appending(path: "CardSheetCreator.zip.sig")
    do {
      try await UpdateDownload.fetch(
        url, to: file, sizeLimit: UpdateVerification.signatureSize, configuration: context.configuration,
        onProgress: { _ in })
    } catch UpdateDownload.DownloadError.exceededSizeLimit {
      throw UpdateVerification.VerificationError.notAuthentic
    }
    return try Data(contentsOf: file)
  }

  /// Progress only moves forward: a late callback must not undo a phase that has since moved on.
  private func record(received: Int64, of total: Int64) {
    guard case .downloading(let current, _) = phase, received > current else { return }
    phase = .downloading(received: received, total: total)
  }

  private func removeStaging(_ staging: URL) {
    do {
      try FileManager.default.removeItem(at: staging)
    } catch {
      Self.logger.error("Update staging not removed: \(error.localizedDescription)")
    }
  }

  /// The helper that swaps the bundle cannot show anything itself: it leaves a file for the next launch.
  private func reportFailedSwap() -> Bool {
    guard FileManager.default.fileExists(atPath: context.resultFile.path) else { return false }
    do {
      try FileManager.default.removeItem(at: context.resultFile)
    } catch {
      Self.logger.error("Update result file not removed: \(error.localizedDescription)")
    }
    phase = .failed(.installFailed)
    return true
  }

  private func latestUpdate() async throws -> AvailableUpdate? {
    try await fetchLatestRelease().update(over: context.installedVersion)
  }

  private func fetchLatestRelease() async throws -> LatestRelease {
    let session = URLSession(configuration: context.configuration)
    defer { session.finishTasksAndInvalidate() }
    var request = URLRequest(url: LatestRelease.endpoint)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    let (body, response) = try await session.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode
    guard status == Self.successStatus else { throw UnexpectedStatus(code: status) }
    return try JSONDecoder().decode(LatestRelease.self, from: body)
  }
}
