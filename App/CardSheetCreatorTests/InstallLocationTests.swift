import Foundation
import Testing

@testable import CardSheetCreator

@Suite struct InstallLocationTests {
  private let directory: URL

  init() throws {
    directory = try UpdateFixtures.temporaryDirectory()
  }

  private func installedApp(in parent: String = "Applications") throws -> URL {
    try UpdateFixtures.makeApp(in: directory.appending(path: parent), version: "0.6.0")
  }

  private func setPermissions(_ permissions: Int, of url: URL) throws {
    try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
  }

  @Test func anAppInAWritableFolderCanBeReplaced() throws {
    let app = try installedApp()

    #expect(UpdateInstaller.canReplace(appAt: app))
  }

  @Test func anAppInAReadOnlyFolderCannotBeReplaced() throws {
    let app = try installedApp()
    let parent = app.deletingLastPathComponent()
    try setPermissions(0o555, of: parent)
    defer { try? setPermissions(0o755, of: parent) }

    #expect(!UpdateInstaller.canReplace(appAt: app))
  }

  @Test func aReadOnlyBundleCannotBeReplaced() throws {
    let app = try installedApp()
    try setPermissions(0o555, of: app)
    defer { try? setPermissions(0o755, of: app) }

    #expect(!UpdateInstaller.canReplace(appAt: app))
  }

  @Test func anAppRunningFromAGatekeeperTranslocationCannotBeReplaced() throws {
    let app = try installedApp(in: "AppTranslocation/\(UUID().uuidString)/d")

    #expect(!UpdateInstaller.canReplace(appAt: app))
  }

  #if DEBUG
    @Test func aDebugBuildNeverInstalls() throws {
      let app = try installedApp()

      #expect(!UpdateContext.live().canInstall(app))
    }
  #endif
}
