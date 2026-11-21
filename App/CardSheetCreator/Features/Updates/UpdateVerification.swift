import CryptoKit
import Domain
import Foundation

// Why: see docs/adr/0007-swift-6-concurrency.md (MainActor by default, explicit @concurrent for background work)
// and docs/adr/0014-signed-in-app-updates.md (the app only installs archives signed with its embedded key).
nonisolated enum UpdateVerification {
  enum VerificationError: Error {
    case notAuthentic
    case unexpectedBundle
  }

  /// Base64 of the public key that `scripts/update-signing.swift` prints. `release.sh` refuses to publish
  /// with a signing key that does not appear here, so no release can ship while this is empty.
  private static let publicKeyBase64 = "vwNppFEcWfa/sLuAvaiKs041sjEkbGIg6qUm8m2J8mA="

  static let embeddedPublicKey = Data(base64Encoded: publicKeyBase64) ?? Data()

  private static let bundleIdentifier = "com.pololops.CardSheetCreator"
  private static let versionKey = "CFBundleShortVersionString"

  /// Fails closed: anything short of a valid signature over the exact bytes of `archive` throws.
  @concurrent static func verifySignature(archive: URL, signature: Data, publicKey: Data) async throws {
    guard signature.count == LatestRelease.signatureSize else { throw VerificationError.notAuthentic }
    let key = try trustedKey(from: publicKey)
    let archiveBytes = try Data(contentsOf: archive, options: .mappedIfSafe)
    guard key.isValidSignature(signature, for: archiveBytes) else { throw VerificationError.notAuthentic }
  }

  /// A genuine signature only proves who built the archive: the bundle inside must also be the app
  /// the release announced, or an older signed build could be replayed under a newer tag.
  @concurrent static func verifyStagedBundle(at app: URL, expectedVersion: SemanticVersion) async throws {
    let info = try infoDictionary(of: app)
    guard info["CFBundleIdentifier"] as? String == bundleIdentifier,
      info[versionKey] as? String == expectedVersion.description
    else { throw VerificationError.unexpectedBundle }
  }

  private static func trustedKey(from rawKey: Data) throws -> Curve25519.Signing.PublicKey {
    do {
      return try Curve25519.Signing.PublicKey(rawRepresentation: rawKey)
    } catch {
      throw VerificationError.notAuthentic
    }
  }

  private static func infoDictionary(of app: URL) throws -> [String: Any] {
    do {
      let plist = try Data(contentsOf: app.appending(path: "Contents/Info.plist"))
      let info = try PropertyListSerialization.propertyList(from: plist, format: nil)
      guard let dictionary = info as? [String: Any] else { throw VerificationError.unexpectedBundle }
      return dictionary
    } catch {
      throw VerificationError.unexpectedBundle
    }
  }
}
