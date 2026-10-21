import Domain
import Foundation
import Testing

@testable import Storage

@Suite struct FileLibraryStoreTests {
  private let library: TemporaryLibrary
  private let template = Template.standardDefault(id: UUID(), now: Date(timeIntervalSince1970: 1_000))

  init() throws {
    library = try TemporaryLibrary()
  }

  private func makeStore(debounce: Duration = .seconds(60)) -> FileLibraryStore {
    FileLibraryStore(root: library.root, debounce: debounce)
  }

  private func sheet(images: [ImageRef]) -> Sheet {
    Sheet(
      id: UUID(), name: "Lune", geometry: template.geometry, sourceTemplateID: template.id, fillMode: .list,
      images: images, crops: ["a": CropAnchor(x: 0.2, y: 0.5)], createdAt: Date(timeIntervalSince1970: 2_000),
      updatedAt: Date(timeIntervalSince1970: 3_000))
  }

  @Test func emptyLibraryLoadsNothing() async throws {
    let snapshot = try await makeStore().loadAll()

    #expect(snapshot.templates.isEmpty)
    #expect(snapshot.sheets.isEmpty)
    #expect(snapshot.printSettings == PrintSettings())
  }

  @Test func savedTemplatesAndSheetsSurviveARelaunch() async throws {
    let store = makeStore()
    let saved = sheet(images: [ImageRef(sha256: "a", fileExtension: "png", originalName: "lune.png")])
    await store.save(template)
    await store.save(saved)
    try await store.flush()

    let snapshot = try await makeStore().loadAll()

    #expect(snapshot.templates == [template])
    #expect(snapshot.sheets == [saved])
    #expect(snapshot.sheets.first?.images.first?.originalName == "lune.png")
  }

  @Test func printSettingsSurviveARelaunch() async throws {
    let store = makeStore()
    let settings = PrintSettings(printerName: "Canon G5000 series", quality: .draft)
    await store.save(settings)
    try await store.flush()

    #expect(try await makeStore().loadAll().printSettings == settings)
  }

  @Test func driverSettingsSurviveARelaunch() async throws {
    let store = makeStore()
    let driver = DriverSettings(data: Data([0x01, 0x02, 0x03]), fingerprint: "Canon G5000 series|1.0")
    let settings = PrintSettings(
      printerName: "Canon G5000 series", quality: .draft, driverSettings: ["Canon G5000 series": driver])
    await store.save(settings)
    try await store.flush()

    #expect(try await makeStore().loadAll().printSettings == settings)
  }

  @Test func settingsWrittenBeforeDriverSettingsStillLoad() async throws {
    try FileManager.default.createDirectory(at: library.root, withIntermediateDirectories: true)
    let legacyJSON = #"{"schemaVersion":1,"payload":{"printerName":"Canon G5000 series","quality":"draft"}}"#
    try Data(legacyJSON.utf8).write(to: library.root.appendingPathComponent("settings.json"))

    let settings = try await makeStore().loadAll().printSettings

    #expect(settings.quality == .draft)
    #expect(settings.driverSettings.isEmpty)
  }

  @Test func writesLeaveNoTemporaryFileBehind() async throws {
    let store = makeStore()
    await store.save(template)
    try await store.flush()

    #expect(try library.files(in: "templates") == ["\(template.id.uuidString).json"])
  }

  @Test func deletedSheetIsGoneAfterARelaunch() async throws {
    let store = makeStore()
    let saved = sheet(images: [])
    await store.save(saved)
    try await store.flush()
    await store.deleteSheet(id: saved.id)
    try await store.flush()

    #expect(try await makeStore().loadAll().sheets.isEmpty)
  }

  @Test func changesWaitForTheDebounceBeforeHittingTheDisk() async throws {
    let store = makeStore(debounce: .seconds(60))

    await store.save(template)

    #expect(try library.files(in: "templates").isEmpty)
  }

  @Test func debouncedChangesAreWrittenWithoutAFlush() async throws {
    let store = makeStore(debounce: .milliseconds(20))

    await store.save(template)
    try await Task.sleep(for: .milliseconds(400))

    #expect(try library.files(in: "templates").count == 1)
  }

  @Test func importingTheSameContentTwiceKeepsOneCopy() async throws {
    let first = try library.pickedPNG(named: "lune.png")
    let copy = library.picked.appendingPathComponent("lune copie.png")
    try FileManager.default.copyItem(at: first, to: copy)

    let report = await makeStore().importImages(at: [first, copy])

    #expect(report.imported.count == 2)
    #expect(report.imported[0] == report.imported[1])
    #expect(try library.files(in: "images").count == 1)
  }

  @Test func importKeepsTheSelectionOrderAndOriginalNames() async throws {
    let dark = try library.pickedPNG(named: "nuit.png", gray: 0.1)
    let light = try library.pickedPNG(named: "jour.png", gray: 0.9)

    let report = await makeStore().importImages(at: [light, dark])

    #expect(report.imported.map(\.originalName) == ["jour.png", "nuit.png"])
  }

  @Test func unreadableAndUnsupportedFilesAreSkippedWithAReason() async throws {
    let good = try library.pickedPNG(named: "ok.png")
    let broken = try library.pickedText(named: "cassée.png")
    let text = try library.pickedText(named: "notes.txt")

    let report = await makeStore().importImages(at: [good, broken, text])

    #expect(report.imported.count == 1)
    #expect(
      report.skipped == [
        SkippedFile(fileName: "cassée.png", reason: .unreadable),
        SkippedFile(fileName: "notes.txt", reason: .unsupportedFormat),
      ])
  }

  @Test func gifImagesAreImported() async throws {
    let gif = try library.pickedImage(named: "étoile.gif", type: .gif)

    let report = await makeStore().importImages(at: [gif])

    #expect(report.imported.map(\.originalName) == ["étoile.gif"])
  }

  @Test func importedImageIsReadableAtItsLibraryURL() async throws {
    let store = makeStore()
    let report = await store.importImages(at: [try library.pickedPNG(named: "lune.png")])

    let ref = try #require(report.imported.first)

    #expect(FileManager.default.fileExists(atPath: store.imageURL(for: ref).path))
  }

  @Test func imagesNoSheetUsesArePurged() async throws {
    let store = makeStore()
    let report = await store.importImages(at: [
      try library.pickedPNG(named: "a.png", gray: 0.2), try library.pickedPNG(named: "b.png", gray: 0.8),
    ])
    let kept = try #require(report.imported.first)

    try await store.purgeImages(notIn: [kept.sha256])

    #expect(try library.files(in: "images") == [kept.fileName])
  }

  @Test func libraryWrittenByANewerVersionIsRefused() async throws {
    try FileManager.default.createDirectory(at: library.root, withIntermediateDirectories: true)
    try Data(#"{"schemaVersion":99}"#.utf8).write(to: library.root.appendingPathComponent("manifest.json"))

    await #expect(throws: StorageError.newerSchema(found: 99)) { try await makeStore().loadAll() }
  }
}
