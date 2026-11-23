import Domain
import Foundation

/// The GitHub side of an update check: one request for the latest release, decoded.
nonisolated enum ReleaseFeed {
  static func latest(configuration: URLSessionConfiguration) async throws -> LatestRelease {
    let session = URLSession(configuration: configuration)
    defer { session.finishTasksAndInvalidate() }
    var request = URLRequest(url: LatestRelease.endpoint)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    let (body, response) = try await session.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode
    guard status == UpdateDownload.successStatus else {
      throw UpdateDownload.DownloadError.unexpectedStatus(status)
    }
    return try JSONDecoder().decode(LatestRelease.self, from: body)
  }
}
