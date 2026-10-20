import Foundation
import Testing

@testable import Storage

@Suite struct MigratorTests {
  @Test func stepsRunInOrderFromTheStoredVersion() throws {
    let migrator = Migrator(steps: [
      Migrator.Step(from: 1) { $0["trail"] = "\($0["trail"] ?? "")a" },
      Migrator.Step(from: 2) { $0["trail"] = "\($0["trail"] ?? "")b" },
    ])

    let migrated = try migrator.migrate(["trail": ""], from: 1)

    #expect(migrated["trail"] as? String == "ab")
  }

  @Test func currentVersionIsLeftUntouched() throws {
    let migrator = Migrator(steps: [Migrator.Step(from: 1) { $0["touched"] = true }])

    let migrated = try migrator.migrate(["name": "Lune"], from: 2)

    #expect(migrated["touched"] == nil)
  }

  @Test func newerVersionIsRefused() {
    let migrator = Migrator(steps: [])

    #expect(throws: StorageError.newerSchema(found: 5)) { try migrator.migrate([:], from: 5) }
  }
}
