import Foundation
import Testing

@testable import Storage

@Suite struct LibraryRelocationTests {
  private let supportRoot: URL
  private let container: URL
  private var target: URL { supportRoot.appendingPathComponent("Library") }
  private var marker: URL { supportRoot.appendingPathComponent(".adopted") }

  init() {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    supportRoot = base.appendingPathComponent("AppSupport/CardSheetCreator")
    container = base.appendingPathComponent("Container/Library")
  }

  private func fill(_ folder: URL, with files: [String: Data]) throws {
    for (path, bytes) in files {
      let url = folder.appendingPathComponent(path)
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try bytes.write(to: url)
    }
  }

  private func makeContainer() throws {
    try fill(
      container,
      with: [
        "manifest.json": Data(#"{"schemaVersion":1}"#.utf8),
        "templates/a.json": Data("template".utf8),
        "images/photo.png": Data((0..<256).map { UInt8($0) }),
      ])
  }

  private func snapshot(of folder: URL) throws -> [String: Data] {
    let paths = try FileManager.default.subpathsOfDirectory(atPath: folder.path)
    var files: [String: Data] = [:]
    for path in paths {
      let url = folder.appendingPathComponent(path)
      if (try url.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true {
        files[path] = try Data(contentsOf: url)
      }
    }
    return files
  }

  private func siblings() throws -> [String] {
    guard FileManager.default.fileExists(atPath: supportRoot.path) else { return [] }
    return try FileManager.default.contentsOfDirectory(atPath: supportRoot.path).sorted()
  }

  private func adopt() throws {
    try FileLibraryStore.adoptSandboxedLibrary(from: container, into: target)
  }

  @Test func theSandboxedLibraryLivesInsideTheAppContainer() {
    let home = URL(filePath: "/Users/someone")

    let root = FileLibraryStore.sandboxedRoot(bundleIdentifier: "com.pololops.CardSheetCreator", home: home)

    #expect(
      root.path
        == "/Users/someone/Library/Containers/com.pololops.CardSheetCreator/Data/Library/Application Support/CardSheetCreator/Library"
    )
  }

  @Test func copiesTheContainerLibraryToTheTarget() throws {
    try makeContainer()

    try adopt()

    #expect(try snapshot(of: target) == snapshot(of: container))
  }

  @Test func neverModifiesTheContainer() throws {
    try makeContainer()
    let before = try snapshot(of: container)

    try adopt()

    #expect(try snapshot(of: container) == before)
  }

  @Test func recordsTheAdoptionWithAMarker() throws {
    try makeContainer()

    try adopt()

    #expect(FileManager.default.fileExists(atPath: marker.path))
  }

  @Test func adoptsOnlyOnce() throws {
    try makeContainer()
    try adopt()
    try fill(target, with: ["templates/made-later.json": Data("new".utf8)])
    let afterFirstRun = try snapshot(of: target)

    try adopt()

    #expect(try snapshot(of: target) == afterFirstRun)
    #expect(try siblings() == [".adopted", "Library"])
  }

  @Test(arguments: [true, false])
  func aContainerWithoutLibraryOnlyWritesTheMarker(containerFolderExists: Bool) throws {
    if containerFolderExists {
      try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    }

    try adopt()

    #expect(try siblings() == [".adopted"])
  }

  @Test func anInterimLibraryIsRenamedNeverDeleted() throws {
    try makeContainer()
    let interim = ["templates/interim.json": Data("made after a failed attempt".utf8)]
    try fill(target, with: interim)

    try adopt()

    let datedName = try Regex(#"Library-\d{8}-\d{6}"#)
    let renamed = try siblings().filter { $0.hasPrefix("Library-") }
    let name = try #require(renamed.first)
    #expect(renamed.count == 1)
    #expect(name.wholeMatch(of: datedName) != nil)
    #expect(try snapshot(of: supportRoot.appendingPathComponent(name)) == interim)
    #expect(try snapshot(of: target) == snapshot(of: container))
  }

  @Test func aContainerFolderWithoutManifestIsNotCopied() throws {
    try fill(container, with: ["templates/a.json": Data("orphan".utf8)])

    try adopt()

    #expect(try siblings() == [".adopted"])
  }

  @Test func aRecordedAdoptionLeavesAnExistingTargetUntouched() throws {
    try makeContainer()
    try fill(target, with: ["templates/mine.json": Data("kept".utf8)])
    try Data().write(to: marker)
    let before = try snapshot(of: target)

    try adopt()

    #expect(try snapshot(of: target) == before)
    #expect(try siblings() == [".adopted", "Library"])
  }

  @Test func twoInterimLibrariesRenamedInTheSameSecondBothSurvive() throws {
    try makeContainer()
    let earlier = ["templates/earlier.json": Data("renamed a moment ago".utf8)]
    let decoys = try dateStampedNamesAroundNow().map { name in
      let folder = supportRoot.appendingPathComponent(name)
      try fill(folder, with: earlier)
      return folder
    }
    let interim = ["templates/interim.json": Data("made after a failed attempt".utf8)]
    try fill(target, with: interim)

    try adopt()

    let decoyNames = Set(decoys.map(\.lastPathComponent))
    let renamed = try siblings().filter { $0.hasPrefix("Library-") && !decoyNames.contains($0) }
    let name = try #require(renamed.first)
    #expect(renamed.count == 1)
    #expect(try snapshot(of: supportRoot.appendingPathComponent(name)) == interim)
    for decoy in decoys { #expect(try snapshot(of: decoy) == earlier) }
  }

  @Test func aFailedCopyLeavesNeitherMarkerNorTemporaryFolder() throws {
    try makeContainer()
    let unreadable = try makeTemplateUnreadable()
    defer { restoreAccess(to: unreadable) }

    #expect(throws: (any Error).self) { try adopt() }

    let leftovers = try siblings()
    restoreAccess(to: unreadable)
    try adopt()
    #expect(leftovers.isEmpty)
    #expect(try siblings() == [".adopted", "Library"])
    #expect(try snapshot(of: target) == snapshot(of: container))
  }

  @Test func aFailedAdoptionSucceedsOnTheNextLaunch() throws {
    try makeContainer()
    let unreadable = try makeTemplateUnreadable()
    defer { restoreAccess(to: unreadable) }
    try? adopt()
    restoreAccess(to: unreadable)

    try adopt()

    #expect(try snapshot(of: target) == snapshot(of: container))
    #expect(FileManager.default.fileExists(atPath: marker.path))
  }

  @Test func aFailedCopyKeepsTheInterimLibraryInPlace() throws {
    try makeContainer()
    let interim = ["templates/interim.json": Data("made after a failed attempt".utf8)]
    try fill(target, with: interim)
    let unreadable = try makeTemplateUnreadable()
    defer { restoreAccess(to: unreadable) }

    #expect(throws: (any Error).self) { try adopt() }

    let interimAfterFailure = try snapshot(of: target)
    let siblingsAfterFailure = try siblings()
    restoreAccess(to: unreadable)
    try adopt()
    let renamed = try siblings().filter { $0.hasPrefix("Library-") }
    #expect(interimAfterFailure == interim)
    #expect(siblingsAfterFailure == ["Library"])
    #expect(try renamed.map { try snapshot(of: supportRoot.appendingPathComponent($0)) } == [interim])
    #expect(try snapshot(of: target) == snapshot(of: container))
    #expect(FileManager.default.fileExists(atPath: marker.path))
  }

  private func makeTemplateUnreadable() throws -> URL {
    let template = container.appendingPathComponent("templates/a.json")
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: template.path)
    return template
  }

  private func restoreAccess(to file: URL) {
    try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
  }

  /// Every name a date-stamped rename could pick right now, whichever clock zone or tick it reads.
  private func dateStampedNamesAroundNow() -> Set<String> {
    var names = Set<String>()
    for zone in [TimeZone.current, TimeZone.gmt] {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = zone
      formatter.dateFormat = "yyyyMMdd-HHmmss"
      for offset in -1...3 {
        names.insert("Library-" + formatter.string(from: Date(timeIntervalSinceNow: Double(offset))))
      }
    }
    return names
  }
}
