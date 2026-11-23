import CryptoKit
import Foundation
import Testing

@testable import CardSheetCreator

@Suite struct UpdateSignatureTests {
  private let key = Curve25519.Signing.PrivateKey()
  private let archiveBytes = Data((0..<2_048).map { UInt8($0 % 251) })
  private let archive: URL

  init() throws {
    archive = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).zip")
    try archiveBytes.write(to: archive)
  }

  private func verify(signature: Data, publicKey: Data, archive: URL? = nil) async throws {
    try await UpdateVerification.verifySignature(
      archive: archive ?? self.archive, signature: signature, publicKey: publicKey)
  }

  @Test func acceptsASignatureFromTheTrustedKey() async throws {
    let signature = try key.signature(for: archiveBytes)

    try await verify(signature: signature, publicKey: key.publicKey.rawRepresentation)
  }

  @Test func refusesAnArchiveAlteredByOneByte() async throws {
    let signature = try key.signature(for: archiveBytes)
    var altered = archiveBytes
    altered[0] ^= 0x01
    let alteredArchive = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).zip")
    try altered.write(to: alteredArchive)

    await #expect(throws: UpdateVerification.VerificationError.notAuthentic) {
      try await verify(
        signature: signature, publicKey: key.publicKey.rawRepresentation, archive: alteredArchive)
    }
  }

  @Test func refusesASignatureFromAnotherKey() async throws {
    let forged = try Curve25519.Signing.PrivateKey().signature(for: archiveBytes)

    await #expect(throws: UpdateVerification.VerificationError.notAuthentic) {
      try await verify(signature: forged, publicKey: key.publicKey.rawRepresentation)
    }
  }

  @Test(arguments: [0, 63, 65])
  func refusesASignatureThatIsNotSixtyFourBytes(length: Int) async throws {
    let signature = try key.signature(for: archiveBytes)
    let malformed = Data(signature.prefix(length)) + Data(count: max(0, length - signature.count))

    await #expect(throws: UpdateVerification.VerificationError.notAuthentic) {
      try await verify(signature: malformed, publicKey: key.publicKey.rawRepresentation)
    }
  }

  @Test(arguments: [0, 31, 33])
  func refusesAKeyThatIsNotThirtyTwoBytes(length: Int) async throws {
    let signature = try key.signature(for: archiveBytes)

    await #expect(throws: UpdateVerification.VerificationError.notAuthentic) {
      try await verify(signature: signature, publicKey: Data(count: length))
    }
  }

  @Test func failsClosedWhenTheArchiveCannotBeRead() async throws {
    let signature = try key.signature(for: archiveBytes)
    let missing = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).zip")

    await #expect(throws: (any Error).self) {
      try await verify(signature: signature, publicKey: key.publicKey.rawRepresentation, archive: missing)
    }
  }

  @Test func theEmbeddedKeyIsAValidEd25519PublicKey() throws {
    _ = try Curve25519.Signing.PublicKey(rawRepresentation: UpdateVerification.embeddedPublicKey)
  }
}
