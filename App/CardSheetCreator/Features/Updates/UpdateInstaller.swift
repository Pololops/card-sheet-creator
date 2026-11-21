import Foundation

struct HelperJob {
  let processID: Int32
  let app: URL
  let staged: URL
  let staging: URL
  let resultFile: URL
  let opener: URL
  let timeoutSeconds: Int
}

enum UpdateInstaller {
  static func canReplace(appAt app: URL) -> Bool {
    false
  }

  static func launchHelper(_ job: HelperJob) throws {
    throw NotImplemented()
  }
}
