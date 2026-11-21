import Domain
import Foundation
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

  private(set) var phase: Phase?

  @ObservationIgnored private let context: UpdateContext

  init(context: UpdateContext) {
    self.context = context
  }

  var installedVersion: SemanticVersion { SemanticVersion(major: 0, minor: 0, patch: 0) }
  var isBusy: Bool { false }

  func checkAtLaunch() async {}
  func checkFromMenu() async {}
  func install() async {}
  func cancel() {}
  func dismiss() {}
  func revealApp() {}

  static func downloadLabel(received: Int64, total: Int64) -> String { "" }
}
