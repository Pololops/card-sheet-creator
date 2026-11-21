import Domain
import Foundation

enum UpdateVerification {
  enum VerificationError: Error {
    case notAuthentic
    case unexpectedBundle
  }

  static let embeddedPublicKey = Data()

  @concurrent static func verifySignature(archive: URL, signature: Data, publicKey: Data) async throws {
    throw NotImplemented()
  }

  @concurrent static func verifyStagedBundle(at app: URL, expectedVersion: SemanticVersion) async throws {
    throw NotImplemented()
  }
}
