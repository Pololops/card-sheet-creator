import Domain
import Foundation
import Testing

@testable import CardSheetCreator

/// Part of `UpdateControllerTests` so that its serialization covers the shared stub network.
extension UpdateControllerTests {
  private var releaseRequestCount: Int {
    rig.requestedURLs.filter { $0 == LatestRelease.endpoint }.count
  }

  /// Starts a check whose answer is held back, then an install that has begun downloading.
  private func installStartedWhileACheckIsInFlight(
    fromTheMenu: Bool
  ) async throws -> (UpdateController, check: Task<Void, Never>, install: Task<Void, Never>) {
    let controller = try await rig.offeredController(declaredSize: 10_000)
    let requestsBefore = releaseRequestCount
    rig.hold(LatestRelease.endpoint)
    let check = Task {
      if fromTheMenu { await controller.checkFromMenu() } else { await controller.checkAtLaunch() }
    }
    let checkStarted = await UpdateFixtures.eventually { releaseRequestCount > requestsBefore }
    try #require(checkStarted, "the check never reached the network")
    let partialBody = Data(count: UpdateRig.partialDownloadSize)
    rig.serve(StubResponse(body: partialBody, staysOpen: true), at: rig.archiveURL)
    let install = Task { await controller.install() }
    let downloading = await UpdateFixtures.eventually { controller.phase?.hasStartedDownloading == true }
    try #require(downloading, "the download never reported progress")
    return (controller, check, install)
  }

  @Test(arguments: [true, false])
  func aCheckThatEndsAfterTheInstallStartedLeavesTheInstallAlone(fromTheMenu: Bool) async throws {
    let (controller, check, install) = try await installStartedWhileACheckIsInFlight(fromTheMenu: fromTheMenu)

    rig.release(LatestRelease.endpoint)
    await check.value

    #expect(controller.phase?.hasStartedDownloading == true)
    #expect(rig.requestedURLs.filter { $0 == rig.archiveURL }.count == 1)
    controller.cancel()
    await install.value
  }

  @Test func aCheckThatFailsAfterTheInstallStartedLeavesTheInstallAlone() async throws {
    let (controller, check, install) = try await installStartedWhileACheckIsInFlight(fromTheMenu: true)
    rig.serve(StubResponse(status: 500), at: LatestRelease.endpoint)

    rig.release(LatestRelease.endpoint)
    await check.value

    #expect(controller.phase?.hasStartedDownloading == true)
    controller.cancel()
    await install.value
  }

  @Test func dismissingWhileDownloadingChangesNothing() async throws {
    let (controller, install) = try await rig.downloadInProgress()

    controller.dismiss()

    #expect(controller.phase?.hasStartedDownloading == true)
    controller.cancel()
    await install.value
  }
}
