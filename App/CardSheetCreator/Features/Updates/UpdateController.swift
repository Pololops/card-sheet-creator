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

  private static let byteCountStyle = ByteCountFormatStyle(style: .file, locale: Locale(identifier: "fr_FR"))
  private static let logger = Logger(subsystem: "com.pololops.CardSheetCreator", category: "updates")

  private(set) var phase: Phase? {
    didSet { refreshPhaseFlags() }
  }
  /// Stored rather than derived from `phase`: a download ticks `phase` many times, and observers of these
  /// flags (the menu, the presentation) must only rebuild when the flag itself flips.
  private(set) var isBusy = false
  private(set) var isPresenting = false
  /// The sheet keeps showing the version on offer while it downloads and installs it.
  private(set) var offeredVersion: SemanticVersion?

  @ObservationIgnored private let context: UpdateContext
  @ObservationIgnored private var installation: Task<Void, any Error>?

  init(context: UpdateContext) {
    self.context = context
  }

  var installedVersion: SemanticVersion { context.installedVersion }

  /// Silent: only a failed swap or a newer release shows anything, every other outcome is logged at most.
  /// `isBusy` is tested again after the network await: an install may have started meanwhile, and the
  /// answer must not overwrite its progress.
  func checkAtLaunch() async {
    guard !isBusy, !showFailedSwapIfReported() else { return }
    let outcome = await checkOutcome()
    guard case .available = outcome else { return }
    apply(outcome)
  }

  /// The user asked, so unlike the launch check every outcome is answered, unless an install started meanwhile.
  func checkFromMenu() async {
    guard !isBusy else { return }
    apply(await checkOutcome())
  }

  private func checkOutcome() async -> Phase {
    do {
      return try await latestUpdate().map(Phase.available) ?? .upToDate
    } catch {
      Self.logger.error("Update check failed: \(error.localizedDescription)")
      return .failed(.network)
    }
  }

  private func apply(_ outcome: Phase) {
    guard !isBusy else { return }
    phase = outcome
  }

  private func refreshPhaseFlags() {
    let isInstalling =
      switch phase {
      case .downloading, .installing: true
      case .upToDate, .available, .failed, nil: false
      }
    if isInstalling != isBusy { isBusy = isInstalling }
    let isOpen = phase != nil
    if isOpen != isPresenting { isPresenting = isOpen }
  }

  /// Ignored unless an update is on offer: a second tap while one install runs starts nothing.
  func install() async {
    guard case .available(let update) = phase else { return }
    guard context.canInstall(context.installedApp) else {
      phase = .failed(.location)
      return
    }
    offeredVersion = update.version
    phase = .downloading(received: 0, total: update.archiveByteCount)
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
    "Téléchargement… \(received.formatted(byteCountStyle)) sur \(total.formatted(byteCountStyle))"
  }

  private func conclude(_ installation: Task<Void, any Error>, of update: AvailableUpdate) async {
    do {
      try await installation.value
    } catch is CancellationError {
      phase = .available(update)
    } catch is UpdateVerification.VerificationError {
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
    let archive = staging.appending(path: LatestRelease.archiveName)
    let total = update.archiveByteCount
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
    let file = staging.appending(path: LatestRelease.signatureName)
    do {
      try await UpdateDownload.fetch(
        url, to: file, sizeLimit: LatestRelease.signatureSize, configuration: context.configuration,
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

  /// A failed swap is shown like any other failed install: the sheet opens on it.
  private func showFailedSwapIfReported() -> Bool {
    guard UpdateInstaller.consumeFailedSwapResult(at: context.resultFile) else { return false }
    phase = .failed(.installFailed)
    return true
  }

  private func latestUpdate() async throws -> AvailableUpdate? {
    try await ReleaseFeed.latest(configuration: context.configuration).update(over: context.installedVersion)
  }
}
