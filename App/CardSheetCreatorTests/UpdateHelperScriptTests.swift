import Foundation
import Testing

@testable import CardSheetCreator

/// Runs the real helper with real `sh` and `xattr`; only the relaunch (`opener`) is a marker script.
@MainActor @Suite struct UpdateHelperScriptTests {
  private static let quarantine = "com.apple.quarantine"
  private let directory: URL
  private let app: URL
  private let staged: URL
  private let staging: URL
  private let resultFile: URL
  private let opener: URL
  private let relaunchMarker: URL
  private var backup: URL { app.appendingPathExtension("old") }

  init() throws {
    directory = try UpdateFixtures.temporaryDirectory()
    app = directory.appending(path: "Applications/CardSheetCreator.app")
    staging = directory.appending(path: "Staging")
    staged = staging.appending(path: "CardSheetCreator.app")
    resultFile = directory.appending(path: "Support/update-result")
    opener = directory.appending(path: "opener.sh")
    relaunchMarker = directory.appending(path: "relaunched")
    try Self.write("old", intoBundleAt: app)
    try Self.write("new", intoBundleAt: staged)
    try Self.writeOpener(at: opener, recording: relaunchMarker)
  }

  private static func write(_ version: String, intoBundleAt bundle: URL) throws {
    try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
    try Data(version.utf8).write(to: bundle.appending(path: "version.txt"))
  }

  private static func writeOpener(at script: URL, recording marker: URL) throws {
    let body = "#!/bin/sh\nprintf '%s' \"$1\" > '\(marker.path)'\n"
    try Data(body.utf8).write(to: script)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
  }

  private func job(processID: Int32, timeoutSeconds: Int = 30) -> HelperJob {
    HelperJob(
      processID: processID, app: app, staged: staged, staging: staging, resultFile: resultFile,
      opener: opener, timeoutSeconds: timeoutSeconds)
  }

  private func installedVersion() throws -> String {
    try String(contentsOf: app.appending(path: "version.txt"), encoding: .utf8)
  }

  private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

  private func waitForRelaunch() async -> Bool {
    await UpdateFixtures.eventually(timeout: .seconds(10)) { exists(relaunchMarker) }
  }

  /// The identifier of a process that has already exited, like the app once it has quit.
  private func exitedProcessID() throws -> Int32 {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/true")
    try process.run()
    process.waitUntilExit()
    return process.processIdentifier
  }

  /// A process that outlives the caller's children bookkeeping, so its exit is seen by `kill -0` at once.
  private func startSleeper(seconds: Int) throws -> Int32 {
    let shell = Process()
    let output = Pipe()
    shell.executableURL = URL(filePath: "/bin/sh")
    shell.arguments = ["-c", "sleep \(seconds) >/dev/null 2>&1 & echo $!"]
    shell.standardOutput = output
    try shell.run()
    let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    return try #require(Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)))
  }

  private func hasQuarantine(_ url: URL) -> Bool {
    getxattr(url.path, Self.quarantine, nil, 0, 0, 0) >= 0
  }

  @Test func waitsForTheAppToExitBeforeSwapping() async throws {
    let sleeperID = try startSleeper(seconds: 1)
    defer { kill(sleeperID, SIGKILL) }
    let startedAt = ContinuousClock.now

    try UpdateInstaller.launchHelper(job(processID: sleeperID))
    try await Task.sleep(for: .milliseconds(300))
    let versionWhileRunning = try installedVersion()
    let relaunched = await waitForRelaunch()

    #expect(versionWhileRunning == "old")
    #expect(relaunched)
    #expect(ContinuousClock.now - startedAt >= .milliseconds(900))
    #expect(try installedVersion() == "new")
  }

  @Test func relaunchesTheInstalledApp() async throws {
    try UpdateInstaller.launchHelper(job(processID: try exitedProcessID()))

    let relaunched = await waitForRelaunch()

    #expect(relaunched)
    #expect(try String(contentsOf: relaunchMarker, encoding: .utf8) == app.path)
  }

  @Test func leavesNeitherBackupNorStagingBehind() async throws {
    try UpdateInstaller.launchHelper(job(processID: try exitedProcessID()))

    _ = await waitForRelaunch()

    #expect(!exists(backup))
    #expect(!exists(staging))
  }

  @Test func replacesAStaleBackupInsteadOfNestingInIt() async throws {
    try Self.write("stale", intoBundleAt: backup)
    try UpdateInstaller.launchHelper(job(processID: try exitedProcessID()))

    _ = await waitForRelaunch()

    #expect(try installedVersion() == "new")
    #expect(!exists(backup))
  }

  @Test func aStaleBackupNeverReplacesTheInstalledAppWhenTheSwapFails() async throws {
    try Self.write("stale", intoBundleAt: backup)
    try FileManager.default.removeItem(at: staged)
    try UpdateInstaller.launchHelper(job(processID: try exitedProcessID()))

    _ = await waitForRelaunch()

    #expect(try installedVersion() == "old")
  }

  @Test func restoresTheInstalledAppWhenTheSwapFails() async throws {
    try FileManager.default.removeItem(at: staged)
    try UpdateInstaller.launchHelper(job(processID: try exitedProcessID()))

    _ = await waitForRelaunch()

    #expect(try installedVersion() == "old")
    #expect(!exists(backup))
  }

  @Test func recordsAFailedSwapForTheNextLaunch() async throws {
    try FileManager.default.removeItem(at: staged)
    try UpdateInstaller.launchHelper(job(processID: try exitedProcessID()))

    _ = await waitForRelaunch()

    #expect(try String(contentsOf: resultFile, encoding: .utf8) == "failed\n")
  }

  @Test func relaunchesTheOldAppAfterAFailedSwap() async throws {
    try FileManager.default.removeItem(at: staged)
    try UpdateInstaller.launchHelper(job(processID: try exitedProcessID()))

    let relaunched = await waitForRelaunch()

    #expect(relaunched)
    #expect(try String(contentsOf: relaunchMarker, encoding: .utf8) == app.path)
  }

  @Test func stripsTheQuarantineFromTheNewApp() async throws {
    let payload = staged.appending(path: "version.txt")
    for url in [staged, payload] {
      let status = setxattr(url.path, Self.quarantine, "0081;00000000;Safari;", 21, 0, 0)
      try #require(status == 0, "cannot mark the fixture: \(String(cString: strerror(errno)))")
    }
    try UpdateInstaller.launchHelper(job(processID: try exitedProcessID()))

    _ = await waitForRelaunch()

    #expect(!hasQuarantine(app))
    #expect(!hasQuarantine(app.appending(path: "version.txt")))
  }

  @Test func givesUpWhenTheAppNeverExits() async throws {
    let sleeperID = try startSleeper(seconds: 30)
    defer { kill(sleeperID, SIGKILL) }

    try UpdateInstaller.launchHelper(job(processID: sleeperID, timeoutSeconds: 1))
    let gaveUp = await UpdateFixtures.eventually(timeout: .seconds(10)) { exists(resultFile) }
    try await Task.sleep(for: .milliseconds(300))

    #expect(gaveUp)
    #expect(try installedVersion() == "old")
    #expect(!exists(relaunchMarker))
    #expect(!exists(staging))
  }

  @Test func relaunchesTheOldAppWhenTheAppExitsAfterTheHelperGaveUp() async throws {
    let sleeperID = try startSleeper(seconds: 30)
    defer { kill(sleeperID, SIGKILL) }
    try UpdateInstaller.launchHelper(job(processID: sleeperID, timeoutSeconds: 1))
    let gaveUp = await UpdateFixtures.eventually(timeout: .seconds(10)) { exists(resultFile) }
    try #require(gaveUp, "the helper never gave up")
    let relaunchedWhileStillRunning = exists(relaunchMarker)

    kill(sleeperID, SIGKILL)
    let relaunched = await waitForRelaunch()

    #expect(!relaunchedWhileStillRunning)
    #expect(relaunched)
    #expect(try String(contentsOf: relaunchMarker, encoding: .utf8) == app.path)
    #expect(try installedVersion() == "old")
    #expect(try String(contentsOf: resultFile, encoding: .utf8) == "failed\n")
  }
}
