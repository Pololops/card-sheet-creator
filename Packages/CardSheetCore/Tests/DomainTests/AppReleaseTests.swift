import Foundation
import Testing

@testable import Domain

@Suite struct AppReleaseTests {
  private static let downloads = "https://github.com/Pololops/card-sheet-creator/releases/download/v0.7.0"
  private static let archiveURL = "\(downloads)/CardSheetCreator.zip"
  private static let signatureURL = "\(downloads)/CardSheetCreator.zip.sig"
  private let installed = SemanticVersion(major: 0, minor: 6, patch: 0)

  private func asset(_ name: String, url: String, size: Int = 1_000) -> [String: Any] {
    ["name": name, "browser_download_url": url, "size": size]
  }

  private func release(
    tag: String = "v0.7.0", archiveURL: String = Self.archiveURL, archiveSize: Int = 18_000_000,
    signatureURL: String = Self.signatureURL, extraAssets: [[String: Any]] = []
  ) throws -> LatestRelease {
    let assets =
      [
        asset("CardSheetCreator.zip", url: archiveURL, size: archiveSize),
        asset("CardSheetCreator.zip.sig", url: signatureURL, size: 64),
      ] + extraAssets
    let json = try JSONSerialization.data(withJSONObject: ["tag_name": tag, "assets": assets])
    return try JSONDecoder().decode(LatestRelease.self, from: json)
  }

  private func releaseWithoutAssets(named missing: String) throws -> LatestRelease {
    let assets = [
      asset("CardSheetCreator.zip", url: Self.archiveURL),
      asset("CardSheetCreator.zip.sig", url: Self.signatureURL),
    ].filter { $0["name"] as? String != missing }
    let json = try JSONSerialization.data(withJSONObject: ["tag_name": "v0.7.0", "assets": assets])
    return try JSONDecoder().decode(LatestRelease.self, from: json)
  }

  @Test func newerReleaseOffersTheUpdate() throws {
    let update = try release().update(over: installed)

    #expect(
      update
        == AvailableUpdate(
          version: SemanticVersion(major: 0, minor: 7, patch: 0),
          archive: try #require(URL(string: Self.archiveURL)), archiveSize: 18_000_000,
          signature: try #require(URL(string: Self.signatureURL))))
  }

  @Test func sameVersionOffersNothing() throws {
    let sameVersion = SemanticVersion(major: 0, minor: 7, patch: 0)

    #expect(try release().update(over: sameVersion) == nil)
  }

  @Test func olderReleaseOffersNothing() throws {
    let newerInstalled = SemanticVersion(major: 0, minor: 10, patch: 0)

    #expect(try release().update(over: newerInstalled) == nil)
  }

  @Test func ignoresAssetsItDoesNotKnow() throws {
    let extra = asset("Notes.txt", url: "https://example.com/Notes.txt")

    #expect(try release(extraAssets: [extra]).update(over: installed) != nil)
  }

  @Test(arguments: ["CardSheetCreator.zip", "CardSheetCreator.zip.sig"])
  func aMissingAssetIsRefused(missing: String) throws {
    let incomplete = try releaseWithoutAssets(named: missing)

    #expect(throws: ReleaseError.missingAsset) { try incomplete.update(over: installed) }
  }

  @Test(arguments: [
    "http://github.com/Pololops/card-sheet-creator/releases/download/v0.7.0/CardSheetCreator.zip",
    "https://example.com/Pololops/card-sheet-creator/releases/download/v0.7.0/CardSheetCreator.zip",
    "https://github.com.example.com/Pololops/card-sheet-creator/releases/download/v0.7.0/CardSheetCreator.zip",
    "https://github.com/Someone/other-repo/releases/download/v0.7.0/CardSheetCreator.zip",
    "https://github.com/Pololops/card-sheet-creator/archive/v0.7.0.zip",
    "https://github.com/Pololops/card-sheet-creator/releases/download/../../../Someone/other-repo/a.zip",
    "https://github.com/Pololops/card-sheet-creator/releases/download/%2e%2e/%2e%2e/%2e%2e/Someone/a.zip",
    "https://github.com:8443/Pololops/card-sheet-creator/releases/download/v0.7.0/CardSheetCreator.zip",
    "https://attacker@github.com/Pololops/card-sheet-creator/releases/download/v0.7.0/CardSheetCreator.zip",
    "https://github.com@example.com/Pololops/card-sheet-creator/releases/download/v0.7.0/CardSheetCreator.zip",
    "https://github.com/Pololops/card-sheet-creator/releases/download/v0.7.0/CardSheetCreator.zip?x=1",
  ])
  func anArchiveOutsideTheProjectReleasesIsRefused(url: String) throws {
    let forged = try release(archiveURL: url)

    #expect(throws: ReleaseError.untrustedURL) { try forged.update(over: installed) }
  }

  @Test func aHostInAnyCaseIsTheSameHost() throws {
    let shouting = "https://GitHub.com/Pololops/card-sheet-creator/releases/download/v0.7.0"

    let update = try release(
      archiveURL: "\(shouting)/CardSheetCreator.zip", signatureURL: "\(shouting)/CardSheetCreator.zip.sig"
    ).update(over: installed)

    #expect(update?.version == SemanticVersion(major: 0, minor: 7, patch: 0))
  }

  @Test func aSignatureOutsideTheProjectReleasesIsRefused() throws {
    let forged = try release(signatureURL: "https://example.com/CardSheetCreator.zip.sig")

    #expect(throws: ReleaseError.untrustedURL) { try forged.update(over: installed) }
  }

  @Test(arguments: ["CardSheetCreator.zip", "CardSheetCreator.zip.sig"])
  func anAmbiguousAssetIsRefused(duplicated: String) throws {
    let staleCopy = asset(
      duplicated, url: "https://github.com/Pololops/card-sheet-creator/releases/download/v0.6.0/\(duplicated)"
    )
    let ambiguous = try release(extraAssets: [staleCopy])

    #expect(throws: ReleaseError.missingAsset) { try ambiguous.update(over: installed) }
  }

  @Test(arguments: ["latest", "v1.2", "0.7.0-beta", "v0.7.0.1", ""])
  func aTagThatIsNotAVersionIsRefused(tag: String) throws {
    let unversioned = try release(tag: tag)

    #expect(throws: ReleaseError.invalidTag) { try unversioned.update(over: installed) }
  }

  @Test func anArchiveAboveTheLimitIsRefused() throws {
    let huge = try release(archiveSize: 200_000_001)

    #expect(throws: ReleaseError.tooLarge) { try huge.update(over: installed) }
  }

  @Test func anArchiveExactlyAtTheLimitIsAccepted() throws {
    let atLimit = try release(archiveSize: 200_000_000)

    #expect(try atLimit.update(over: installed)?.archiveSize == 200_000_000)
  }

  @Test func asksTheLatestReleaseOfTheProjectRepository() {
    #expect(
      LatestRelease.endpoint.absoluteString
        == "https://api.github.com/repos/Pololops/card-sheet-creator/releases/latest")
  }
}
