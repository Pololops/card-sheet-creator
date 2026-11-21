import Foundation
import Synchronization

// Why: see docs/adr/0007-swift-6-concurrency.md (the delegate runs off the main actor, its state sits in a Mutex).
/// One download of one file: a download task rather than a data task so that the body goes to disk,
/// never to memory, and so that the bytes received are known while it runs.
nonisolated final class UpdateDownload: NSObject, URLSessionDownloadDelegate, Sendable {
  enum DownloadError: Error {
    case unexpectedStatus(Int?)
    case exceededSizeLimit
  }

  private struct State {
    var continuation: CheckedContinuation<Void, any Error>?
    /// Set by the first delegate callback that settles the download; later ones are ignored.
    var outcome: Result<Void, any Error>?
    var lastReportedPercent = -1
  }

  static let successStatus = 200
  private static let fullPercent = 100

  private let destination: URL
  private let sizeLimit: Int64
  private let onProgress: @Sendable (Int64) -> Void
  private let state = Mutex(State())

  private init(destination: URL, sizeLimit: Int, onProgress: @escaping @Sendable (Int64) -> Void) {
    self.destination = destination
    self.sizeLimit = Int64(sizeLimit)
    self.onProgress = onProgress
  }

  /// Saves `url` at `destination` unless it turns out larger than `sizeLimit`. `onProgress` receives the
  /// bytes received, only when the whole percent of `sizeLimit` grows: a download is thousands of callbacks.
  static func fetch(
    _ url: URL, to destination: URL, sizeLimit: Int, configuration: URLSessionConfiguration,
    onProgress: @escaping @Sendable (Int64) -> Void
  ) async throws {
    try Task.checkCancellation()
    let download = UpdateDownload(destination: destination, sizeLimit: sizeLimit, onProgress: onProgress)
    try await download.run(url, configuration: configuration)
  }

  private func run(_ url: URL, configuration: URLSessionConfiguration) async throws {
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    defer { session.finishTasksAndInvalidate() }
    let task = session.downloadTask(with: url)
    task.resume()
    do {
      try await withTaskCancellationHandler {
        try await outcome()
      } onCancel: {
        task.cancel()
      }
    } catch {
      try Task.checkCancellation()
      throw error
    }
  }

  private func outcome() async throws {
    try await withCheckedThrowingContinuation { continuation in
      let settled = state.withLock { state -> Result<Void, any Error>? in
        if let outcome = state.outcome { return outcome }
        state.continuation = continuation
        return nil
      }
      if let settled { continuation.resume(with: settled) }
    }
  }

  private func settle(_ result: Result<Void, any Error>) {
    let continuation = state.withLock { state -> CheckedContinuation<Void, any Error>? in
      guard state.outcome == nil else { return nil }
      state.outcome = result
      return state.continuation.take()
    }
    continuation?.resume(with: result)
  }

  private var isSettled: Bool { state.withLock { $0.outcome != nil } }

  func urlSession(
    _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
  ) {
    guard totalBytesWritten <= sizeLimit else {
      settle(.failure(DownloadError.exceededSizeLimit))
      downloadTask.cancel()
      return
    }
    let percent = Int(totalBytesWritten * Int64(Self.fullPercent) / sizeLimit)
    let isNewPercent = state.withLock { state in
      guard percent > state.lastReportedPercent else { return false }
      state.lastReportedPercent = percent
      return true
    }
    if isNewPercent { onProgress(totalBytesWritten) }
  }

  /// The system deletes `location` as soon as this returns, so the file is moved here, not later.
  func urlSession(
    _ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL
  ) {
    guard !isSettled else { return }
    let status = (downloadTask.response as? HTTPURLResponse)?.statusCode
    guard status == Self.successStatus else {
      settle(.failure(DownloadError.unexpectedStatus(status)))
      return
    }
    do {
      try FileManager.default.moveItem(at: location, to: destination)
      settle(.success(()))
    } catch {
      settle(.failure(error))
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
    settle(error.map { .failure($0) } ?? .success(()))
  }
}
