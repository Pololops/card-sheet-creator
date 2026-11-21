import Domain
import Foundation
import Testing

@testable import CardSheetCreator

@MainActor @Suite(.serialized) struct UpdateControllerTests {
  static let newVersion = SemanticVersion(major: 0, minor: 7, patch: 0)
  /// A refused request, a dropped connection and an answer that is no release are the same to the user:
  /// the release data is unusable.
  private nonisolated static let unusableAnswers = [
    StubResponse(status: 403), StubResponse(status: 429), StubResponse(status: 500),
    StubResponse(failure: .notConnectedToInternet),
    StubResponse(body: Data("<html>Service Unavailable</html>".utf8)),
    StubResponse(body: Data(#"{"assets": []}"#.utf8)),
  ]
  let rig: UpdateRig

  init() throws {
    rig = try UpdateRig()
  }

  @Test func aReleaseEqualToTheInstalledVersionIsUpToDate() async throws {
    try rig.publish(tag: "v0.6.0", bundleVersion: "0.6.0")
    let controller = rig.makeController()

    await controller.checkFromMenu()

    #expect(controller.phase == .upToDate)
  }

  @Test(arguments: [true, false])
  func aNewerReleaseIsOffered(fromTheMenu: Bool) async throws {
    try rig.publish()
    let controller = rig.makeController()

    if fromTheMenu { await controller.checkFromMenu() } else { await controller.checkAtLaunch() }

    #expect(controller.phase?.offeredVersion == Self.newVersion)
  }

  @Test func anUpToDateLaunchCheckStaysSilent() async throws {
    try rig.publish(tag: "v0.6.0", bundleVersion: "0.6.0")
    let controller = rig.makeController()

    await controller.checkAtLaunch()

    #expect(rig.requestedURLs.contains(LatestRelease.endpoint))
    #expect(controller.phase == nil)
  }

  @Test(arguments: unusableAnswers)
  func unusableReleaseDataIsANetworkFailureFromTheMenu(answer: StubResponse) async {
    rig.serve(answer, at: LatestRelease.endpoint)
    let controller = rig.makeController()

    await controller.checkFromMenu()

    #expect(controller.phase == .failed(.network))
  }

  @Test(arguments: unusableAnswers)
  func unusableReleaseDataStaysSilentAtLaunch(answer: StubResponse) async {
    rig.serve(answer, at: LatestRelease.endpoint)
    let controller = rig.makeController()

    await controller.checkAtLaunch()

    #expect(rig.requestedURLs.contains(LatestRelease.endpoint))
    #expect(controller.phase == nil)
  }

  @Test func anUntrustedReleaseIsANetworkFailureFromTheMenu() async throws {
    try rig.publish(downloadsBase: "https://example.com/Pololops/card-sheet-creator/releases/download")
    let controller = rig.makeController()

    await controller.checkFromMenu()

    #expect(controller.phase == .failed(.network))
  }

  @Test func anUntrustedReleaseStaysSilentAtLaunch() async throws {
    try rig.publish(downloadsBase: "https://example.com/Pololops/card-sheet-creator/releases/download")
    let controller = rig.makeController()

    await controller.checkAtLaunch()

    #expect(rig.requestedURLs.contains(LatestRelease.endpoint))
    #expect(controller.phase == nil)
  }

  @Test func checkingAgainAfterAFailureOffersTheUpdateOnceTheNetworkIsBack() async throws {
    rig.serve(StubResponse(status: 500), at: LatestRelease.endpoint)
    let controller = rig.makeController()
    await controller.checkFromMenu()
    try #require(controller.phase == .failed(.network))
    try rig.publish()

    await controller.checkFromMenu()

    #expect(controller.phase?.offeredVersion == Self.newVersion)
  }

  @Test func dismissingTheOfferClearsIt() async throws {
    let controller = try await rig.offeredController()

    controller.dismiss()

    #expect(controller.phase == nil)
  }

  @Test func offeringAnUpdateIsNotBusy() async throws {
    let controller = try await rig.offeredController()

    #expect(!controller.isBusy)
  }

  @Test func aFailedSwapIsReportedAtTheNextLaunchAndForgotten() async throws {
    try rig.publish()
    try rig.leaveFailedSwapResult()
    let controller = rig.makeController()

    await controller.checkAtLaunch()

    #expect(controller.phase == .failed(.installFailed))
    #expect(!FileManager.default.fileExists(atPath: rig.resultFile.path))
  }

  @Test func theLaunchAfterAReportedFailureChecksAgain() async throws {
    try rig.publish()
    try rig.leaveFailedSwapResult()
    let controller = rig.makeController()
    await controller.checkAtLaunch()
    controller.dismiss()

    await controller.checkAtLaunch()

    #expect(controller.phase?.offeredVersion == Self.newVersion)
  }
}
