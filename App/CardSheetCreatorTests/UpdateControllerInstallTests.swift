import CryptoKit
import Domain
import Foundation
import Testing

@testable import CardSheetCreator

/// Part of `UpdateControllerTests` so that its serialization covers the shared stub network.
extension UpdateControllerTests {
  /// Bytes that are no zip, whatever their signature says.
  private var corruptArchive: Data { Data(repeating: 0x5A, count: rig.archive.count) }

  @Test func installingHandsTheVerifiedNewVersionOver() async throws {
    let controller = try await rig.offeredController()

    await controller.install()

    let staged = try #require(rig.launchAttempts.first)
    #expect(rig.launchAttempts.count == 1)
    #expect(try UpdateFixtures.bundleVersion(of: staged.app) == "0.7.0")
  }

  @Test func installingEndsWithTheRestartNotice() async throws {
    let controller = try await rig.offeredController()

    await controller.install()

    #expect(controller.phase == .installing)
  }

  @Test func theRestartNoticeIsBusy() async throws {
    let controller = try await rig.offeredController()

    await controller.install()

    #expect(controller.isBusy)
  }

  @Test func theStagingFolderIsPrivateToTheUser() async throws {
    let controller = try await rig.offeredController()

    await controller.install()

    let staged = try #require(rig.launchAttempts.first)
    let attributes = try FileManager.default.attributesOfItem(atPath: staged.staging.path)
    #expect(attributes[.posixPermissions] as? Int == 0o700)
    #expect(staged.app.path.hasPrefix(staged.staging.path))
  }

  @Test func aSignatureFromAnotherKeyIsNotAuthentic() async throws {
    let controller = try await rig.offeredController(signedBy: Curve25519.Signing.PrivateKey())

    await controller.install()

    #expect(controller.phase == .failed(.notAuthentic))
    #expect(rig.launchAttempts.isEmpty)
  }

  @Test func anArchiveAlteredAfterSigningIsNotAuthentic() async throws {
    let controller = try await rig.offeredController()
    var altered = rig.archive
    altered[altered.count / 2] ^= 0xFF
    rig.serve(StubResponse(body: altered), at: rig.archiveURL)

    await controller.install()

    #expect(controller.phase == .failed(.notAuthentic))
    #expect(rig.launchAttempts.isEmpty)
  }

  @Test func theSignatureIsCheckedBeforeTheArchiveIsUnpacked() async throws {
    let controller = try await rig.offeredController()
    try rig.replaceArchive(with: corruptArchive, signedBy: Curve25519.Signing.PrivateKey())

    await controller.install()

    #expect(controller.phase == .failed(.notAuthentic))
    #expect(rig.launchAttempts.isEmpty)
  }

  @Test func aSignedArchiveThatCannotBeUnpackedFailsTheInstall() async throws {
    let controller = try await rig.offeredController()
    try rig.replaceArchive(with: corruptArchive)

    await controller.install()

    #expect(controller.phase == .failed(.installFailed))
    #expect(rig.launchAttempts.isEmpty)
  }

  @Test(arguments: [("com.example.Impostor", "0.7.0"), ("com.pololops.CardSheetCreator", "0.6.9")])
  func aSignedBundleThatIsNotTheAnnouncedAppIsNotAuthentic(identifier: String, version: String)
    async throws
  {
    let controller = try await rig.offeredController(bundleVersion: version, bundleIdentifier: identifier)

    await controller.install()

    #expect(controller.phase == .failed(.notAuthentic))
    #expect(rig.launchAttempts.isEmpty)
  }

  @Test func anInstallLocationThatCannotBeReplacedIsReportedBeforeDownloading() async throws {
    let controller = try await rig.offeredController(canInstall: false)

    await controller.install()

    #expect(controller.phase == .failed(.location))
    #expect(!rig.requestedURLs.contains(rig.archiveURL))
  }

  @Test func anArchiveLargerThanAnnouncedFailsTheInstall() async throws {
    let controller = try await rig.offeredController(declaredSize: 100)

    await controller.install()

    #expect(controller.phase == .failed(.installFailed))
    #expect(rig.launchAttempts.isEmpty)
  }

  @Test(arguments: ["archive", "signature"])
  func aDownloadRefusedByTheServerFailsTheInstall(asset: String) async throws {
    let controller = try await rig.offeredController()
    rig.serve(StubResponse(status: 404), at: asset == "archive" ? rig.archiveURL : rig.signatureURL)

    await controller.install()

    #expect(controller.phase == .failed(.installFailed))
    #expect(rig.launchAttempts.isEmpty)
  }

  /// An error body longer than a signature must not turn a server failure into an integrity failure.
  @Test(arguments: [403, 429, 500], ["archive", "signature"])
  func aRefusalWithALongBodyFailsTheInstallAndRemovesTheStaging(status: Int, asset: String) async throws {
    let controller = try await rig.offeredController()
    let stagingBefore = rig.stagingFolderCount
    let errorPage = StubResponse(status: status, body: Data(repeating: 0x3C, count: 1_024))
    rig.serve(errorPage, at: asset == "archive" ? rig.archiveURL : rig.signatureURL)

    await controller.install()

    let stagingRemoved = await UpdateFixtures.eventually { rig.stagingFolderCount <= stagingBefore }
    #expect(controller.phase == .failed(.installFailed))
    #expect(rig.launchAttempts.isEmpty)
    #expect(stagingRemoved)
  }

  @Test func aRefusedRelaunchFailsTheInstallAndRemovesTheStaging() async throws {
    let controller = try await rig.offeredController()
    rig.launchFailure = LaunchRefused()

    await controller.install()

    let staged = try #require(rig.launchAttempts.first)
    #expect(controller.phase == .failed(.installFailed))
    #expect(!FileManager.default.fileExists(atPath: staged.staging.path))
  }

  @Test func reportsTheBytesReceivedAgainstTheAnnouncedSize() async throws {
    let (controller, install) = try await rig.downloadInProgress()

    guard case .downloading(let received, let total) = controller.phase else {
      Issue.record("expected a download in progress, got \(String(describing: controller.phase))")
      return
    }
    #expect(received > 0 && received <= total)
    #expect(total == 10_000)
    controller.cancel()
    await install.value
  }

  @Test func cancellingTheDownloadGoesBackToTheOffer() async throws {
    let (controller, install) = try await rig.downloadInProgress()

    controller.cancel()
    await install.value

    #expect(controller.phase?.offeredVersion == Self.newVersion)
    #expect(rig.launchAttempts.isEmpty)
  }

  @Test func cancellingTheDownloadRemovesTheFilesItCreated() async throws {
    let stagingBefore = rig.stagingFolderCount
    let partialsBefore = rig.partialDownloads
    let (controller, install) = try await rig.downloadInProgress()
    try #require(rig.stagingFolderCount > stagingBefore, "nothing is staged during a download")

    controller.cancel()
    await install.value

    let stagingRemoved = await UpdateFixtures.eventually { rig.stagingFolderCount <= stagingBefore }
    let archiveRemoved = await UpdateFixtures.eventually { rig.partialDownloads.isSubset(of: partialsBefore) }
    #expect(stagingRemoved)
    #expect(archiveRemoved)
  }

  @Test func aMenuCheckWhileDownloadingChangesNothing() async throws {
    let (controller, install) = try await rig.downloadInProgress()
    let requestsBefore = rig.requestedURLs.count

    await controller.checkFromMenu()

    #expect(controller.isBusy)
    #expect(controller.phase?.hasStartedDownloading == true)
    #expect(rig.requestedURLs.count == requestsBefore)
    controller.cancel()
    await install.value
  }

  @Test func aSecondInstallWhileOneRunsDoesNotDownloadAgain() async throws {
    let (controller, install) = try await rig.downloadInProgress()

    await controller.install()

    let archiveRequests = rig.requestedURLs.filter { $0 == rig.archiveURL }
    #expect(archiveRequests.count == 1)
    controller.cancel()
    await install.value
  }

  @Test func labelsTheDownloadInFrenchBytes() {
    let label = UpdateController.downloadLabel(received: 7_600_000, total: 18_200_000)

    #expect(Self.withPlainSpaces(label) == "Téléchargement… 7,6 Mo sur 18,2 Mo")
  }

  /// The byte formatter separates the number from its unit with a narrow no-break space.
  private static func withPlainSpaces(_ text: String) -> String {
    text.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
  }
}
