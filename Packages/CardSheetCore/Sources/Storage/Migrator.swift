/// Upgrades stored JSON written by an older app version, one schema version at a time.
struct Migrator: Sendable {
  struct Step: Sendable {
    let from: Int
    let transform: @Sendable (inout [String: Any]) -> Void
  }

  static let library = Migrator(steps: [])

  let steps: [Step]

  var currentVersion: Int { (steps.map(\.from).max() ?? 0) + 1 }

  func migrate(_ payload: [String: Any], from version: Int) throws(StorageError) -> [String: Any] {
    guard version <= currentVersion else { throw .newerSchema(found: version) }
    var migrated = payload
    for step in steps.sorted(by: { $0.from < $1.from }) where step.from >= version {
      step.transform(&migrated)
    }
    return migrated
  }
}
