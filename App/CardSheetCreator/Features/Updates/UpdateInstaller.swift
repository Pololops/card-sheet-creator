import Foundation

// Why: see docs/adr/0014-signed-in-app-updates.md (a detached helper swaps the bundle once the app has quit).
struct HelperJob {
  let processID: Int32
  let app: URL
  let staged: URL
  let staging: URL
  let resultFile: URL
  let opener: URL
  let timeoutSeconds: Int
}

nonisolated enum UpdateInstaller {
  enum InstallerError: Error {
    case extractionFailed(status: Int32)
    case appMissingFromArchive
  }

  private static let translocationMarker = "/AppTranslocation/"
  private static let stagingPermissions = 0o700
  private static let extractedFolderName = "extracted"
  private static let appName = "CardSheetCreator.app"

  /// Replacing a bundle needs write access to both the bundle and the folder that holds it. An app that
  /// Gatekeeper runs from a translocated copy has neither a stable path nor a place to be replaced.
  static func canReplace(appAt app: URL) -> Bool {
    guard !app.path.contains(translocationMarker) else { return false }
    let files = FileManager.default
    let parent = app.deletingLastPathComponent()
    return files.isWritableFile(atPath: parent.path) && files.isWritableFile(atPath: app.path)
  }

  /// On the volume of the installed app so that the helper's final move is a rename, never a copy,
  /// and private to the user so that nobody can swap the archive between verification and unpacking.
  static func makeStagingDirectory(appropriateFor app: URL) throws -> URL {
    let staging = try FileManager.default.url(
      for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: app, create: true)
    try FileManager.default.setAttributes([.posixPermissions: stagingPermissions], ofItemAtPath: staging.path)
    return staging
  }

  /// Unpacks `archive` next to it and returns the app found inside.
  @concurrent static func extract(archive: URL, into staging: URL) async throws -> URL {
    let destination = staging.appending(path: extractedFolderName)
    let ditto = Process()
    ditto.executableURL = URL(filePath: "/usr/bin/ditto")
    ditto.arguments = ["-x", "-k", archive.path, destination.path]
    try ditto.run()
    ditto.waitUntilExit()
    guard ditto.terminationStatus == 0 else {
      throw InstallerError.extractionFailed(status: ditto.terminationStatus)
    }
    let app = destination.appending(path: appName)
    guard FileManager.default.fileExists(atPath: app.path) else { throw InstallerError.appMissingFromArchive }
    return app
  }

  /// The helper outlives the app and shares none of its pipes: with stdio on the null device and SIGHUP
  /// ignored, quitting the app cannot kill it or block it on a closed stream.
  static func launchHelper(_ job: HelperJob) throws {
    let helper = Process()
    helper.executableURL = URL(filePath: "/bin/sh")
    helper.arguments = [
      "-c", helperScript, "update-helper", String(job.processID), job.app.path, job.staged.path,
      job.staging.path, job.resultFile.path, job.opener.path, String(job.timeoutSeconds),
    ]
    helper.standardInput = FileHandle.nullDevice
    helper.standardOutput = FileHandle.nullDevice
    helper.standardError = FileHandle.nullDevice
    try helper.run()
  }

  /// Constant: the shell only ever sees positional arguments, never text built from a release.
  /// A failed swap restores the old app and relaunches it. A helper that gave up waiting for the app to
  /// exit leaves the old app untouched and relaunches it once the app is gone: the app is quitting anyway,
  /// and a slow flush to disk must still end with it reopened.
  private static let helperScript = #"""
    trap '' HUP
    pid=$1 app=$2 staged=$3 staging=$4 result=$5 opener=$6 timeout=$7
    backup="$app.old"
    rm -f "$result"

    record_failure() {
      mkdir -p "$(dirname "$result")"
      printf 'failed\n' > "$result"
      rm -rf "$staging"
    }
    fail() {
      record_failure
      "$opener" "$app"
      exit 1
    }

    give_up() {
      record_failure
      while kill -0 "$pid" 2>/dev/null; do sleep 0.1; done
      "$opener" "$app"
      exit 1
    }

    waited=0
    while kill -0 "$pid" 2>/dev/null; do
      if [ "$waited" -ge $((timeout * 10)) ]; then
        give_up
      fi
      sleep 0.1
      waited=$((waited + 1))
    done

    rm -rf "$backup"
    mv "$app" "$backup" || fail
    mv "$staged" "$app" || { mv "$backup" "$app"; fail; }
    xattr -dr com.apple.quarantine "$app" 2>/dev/null
    rm -rf "$backup" "$staging"
    "$opener" "$app"
    """#
}
