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

  @ObservationIgnored private let context: UpdateContext

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
  func checkAtLaunch() async {
    guard !isBusy else { return }
    if reportFailedSwap() { return }
    do {
      if let update = try await latestUpdate() { phase = .available(update) }
    } catch {
      Self.logger.error("Launch update check failed: \(error.localizedDescription)")
    }
  }

  /// The user asked, so unlike the launch check every outcome is answered.
  func checkFromMenu() async {
    guard !isBusy else { return }
    do {
      let update = try await latestUpdate()
      phase = update.map(Phase.available) ?? .upToDate
    } catch {
      Self.logger.error("Menu update check failed: \(error.localizedDescription)")
      phase = .failed(.network)
    }
  }

  func install() async {}
  func cancel() {}
  func dismiss() { phase = nil }
  func revealApp() {}

  static func downloadLabel(received: Int64, total: Int64) -> String { "" }

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
