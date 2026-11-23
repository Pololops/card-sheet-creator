import Foundation
import Testing

@testable import CardSheetCreator

/// Part of `UpdateControllerTests` so that its serialization covers the shared stub network.
extension UpdateControllerTests {
  /// Larger than the 64 bytes of a signature, so that it can only be something else.
  private nonisolated static let oversizedSignatureSize = 200
  private nonisolated static let truncatedSignatureSize = 10

  /// Zips a folder that holds no app at all.
  private func zipWithoutTheApp() throws -> Data {
    let workspace = try UpdateFixtures.temporaryDirectory()
    let folder = workspace.appending(path: "Other")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data("not an app".utf8).write(to: folder.appending(path: "readme.txt"))
    let zip = workspace.appending(path: "Other.zip")
    try UpdateFixtures.archive(of: folder, to: zip)
    return try Data(contentsOf: zip)
  }

  @Test(arguments: [oversizedSignatureSize, truncatedSignatureSize])
  func aSignatureThatIsNotTheSizeOfASignatureIsNotAuthentic(size: Int) async throws {
    let controller = try await rig.offeredController()
    rig.serve(StubResponse(body: Data(count: size)), at: rig.signatureURL)

    await controller.install()

    #expect(controller.phase == .failed(.notAuthentic))
    #expect(rig.launchAttempts.isEmpty)
  }

  @Test func aSignedArchiveWithoutTheAppIsNotAuthentic() async throws {
    let controller = try await rig.offeredController()
    try rig.replaceArchive(with: try zipWithoutTheApp())

    await controller.install()

    #expect(controller.phase == .failed(.notAuthentic))
    #expect(rig.launchAttempts.isEmpty)
  }
}
