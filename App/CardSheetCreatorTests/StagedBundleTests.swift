import Domain
import Foundation
import Testing

@testable import CardSheetCreator

@Suite struct StagedBundleTests {
  private static let expectedVersion = SemanticVersion(major: 0, minor: 7, patch: 0)
  private let directory: URL

  init() throws {
    directory = try UpdateFixtures.temporaryDirectory()
  }

  private func verify(_ app: URL) async throws {
    try await UpdateVerification.verifyStagedBundle(at: app, expectedVersion: Self.expectedVersion)
  }

  @Test func acceptsTheAnnouncedAppAndVersion() async throws {
    let app = try UpdateFixtures.makeApp(in: directory, version: "0.7.0")

    try await verify(app)
  }

  @Test func refusesAnotherBundleIdentifier() async throws {
    let impostor = "com.example.Impostor"
    let app = try UpdateFixtures.makeApp(in: directory, bundleIdentifier: impostor, version: "0.7.0")

    await #expect(throws: UpdateVerification.VerificationError.unexpectedBundle) { try await verify(app) }
  }

  @Test(arguments: ["0.6.9", "0.7.1", "garbage"])
  func refusesAnotherVersion(version: String) async throws {
    let app = try UpdateFixtures.makeApp(in: directory, version: version)

    await #expect(throws: UpdateVerification.VerificationError.unexpectedBundle) { try await verify(app) }
  }

  @Test func refusesABundleWithoutInfoPlist() async throws {
    let app = directory.appending(path: "CardSheetCreator.app")
    try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)

    await #expect(throws: UpdateVerification.VerificationError.unexpectedBundle) { try await verify(app) }
  }

  @Test func refusesAnInfoPlistThatIsNotAPropertyList() async throws {
    let app = try UpdateFixtures.makeApp(in: directory, version: "0.7.0")
    try Data("not a plist".utf8).write(to: app.appending(path: "Contents/Info.plist"))

    await #expect(throws: UpdateVerification.VerificationError.unexpectedBundle) { try await verify(app) }
  }
}
