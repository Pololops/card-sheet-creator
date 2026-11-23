// Ed25519 signing of the release archive, with CryptoKit alone.
//
//   swift scripts/update-signing.swift generate
//       Prints a new key pair once. Refuses when the Keychain already holds a signing key.
//   security find-generic-password -a "$USER" -s card-sheet-creator-update-signing -w \
//     | swift scripts/update-signing.swift sign <file>
//       Reads the base64 private key on stdin, writes <file>.sig and prints the public key.
//
// The private key only travels through stdout (generate) and stdin (sign): it never touches the disk,
// and the Security framework stays out so that nothing here can read the Keychain on its own.
import CryptoKit
import Foundation

let keychainService = "card-sheet-creator-update-signing"
let signatureLength = 64

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("error: \(message)\n".utf8))
  exit(1)
}

func keychainAccount() -> String {
  ProcessInfo.processInfo.environment["USER"] ?? NSUserName()
}

/// Asks `security` for the item's attributes only (no `-w`), so the lookup never reveals the secret.
func keychainHoldsSigningKey() -> Bool {
  let lookup = Process()
  lookup.executableURL = URL(filePath: "/usr/bin/security")
  lookup.arguments = ["find-generic-password", "-a", keychainAccount(), "-s", keychainService]
  lookup.standardOutput = FileHandle.nullDevice
  lookup.standardError = FileHandle.nullDevice
  do { try lookup.run() } catch { fail("cannot run /usr/bin/security: \(error.localizedDescription)") }
  lookup.waitUntilExit()
  return lookup.terminationStatus == 0
}

func generate() {
  guard !keychainHoldsSigningKey() else {
    fail("a signing key already exists in the Keychain (\(keychainService)); refusing to replace it")
  }
  let key = Curve25519.Signing.PrivateKey()
  print("PRIVATE KEY (shown once, never stored by this script):")
  print(key.rawRepresentation.base64EncodedString())
  print("\nStore it in your login Keychain, pasting the private key at the prompt:")
  // Why: `-T ""` trusts no application, so macOS asks for the login password on every read of the key
  // instead of handing it to any process that runs as this user.
  print("security add-generic-password -a \"$USER\" -s \(keychainService) -T \"\" -w")
  print("\nPUBLIC KEY (embed it in UpdateVerification.swift):")
  print(key.publicKey.rawRepresentation.base64EncodedString())
  print("\nBack the private key up offline now: without it no update can ever be signed again.")
}

func readPrivateKeyFromStandardInput() -> Curve25519.Signing.PrivateKey {
  guard let line = readLine(strippingNewline: true),
    let raw = Data(base64Encoded: line.trimmingCharacters(in: .whitespacesAndNewlines))
  else { fail("expected the base64 private key on stdin") }
  do { return try Curve25519.Signing.PrivateKey(rawRepresentation: raw) } catch {
    fail("stdin is not an Ed25519 private key: \(error.localizedDescription)")
  }
}

func sign(fileAt path: String) {
  let key = readPrivateKeyFromStandardInput()
  let file = URL(filePath: path)
  let signatureFile = URL(filePath: path + ".sig")
  do {
    let content = try Data(contentsOf: file)
    try key.signature(for: content).write(to: signatureFile, options: .atomic)
    // Verified from the bytes on disk: this is what the app will download and check.
    let written = try Data(contentsOf: signatureFile)
    guard written.count == signatureLength, key.publicKey.isValidSignature(written, for: content) else {
      fail("the signature written to \(signatureFile.path) does not verify")
    }
  } catch {
    fail("cannot sign \(path): \(error.localizedDescription)")
  }
  print(key.publicKey.rawRepresentation.base64EncodedString())
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "generate" where arguments.count == 1: generate()
case "sign" where arguments.count == 2: sign(fileAt: arguments[1])
default: fail("usage: update-signing.swift generate | sign <file>")
}
