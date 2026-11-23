import Foundation
import Synchronization

/// What the network answers for one URL.
nonisolated struct StubResponse: Sendable {
  var status = 200
  var body = Data()
  /// Keeps the connection open after the body, like a download that has not finished.
  var staysOpen = false
  /// Fails the request at transport level instead of answering.
  var failure: URLError.Code?
}

/// Stands in for the network at the `URLSession` boundary. One shared route table: suites that use it
/// run `.serialized`.
nonisolated final class StubURLProtocol: URLProtocol {
  private struct Network {
    var responses: [URL: StubResponse] = [:]
    var requested: [URL] = []
    var held: Set<URL> = []
  }

  private static let holdPollInterval = DispatchTimeInterval.milliseconds(10)

  private static let network = Mutex(Network())

  static var configuration: URLSessionConfiguration {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return configuration
  }

  static var requestedURLs: [URL] { network.withLock { $0.requested } }

  static func serve(_ responses: [URL: StubResponse]) {
    network.withLock { $0 = Network(responses: responses) }
  }

  static func serve(_ response: StubResponse, at url: URL) {
    network.withLock { $0.responses[url] = response }
  }

  /// Requests to `url` stay unanswered until `release(_:)`: lets a test order two things on the network.
  static func hold(_ url: URL) {
    network.withLock { _ = $0.held.insert(url) }
  }

  static func release(_ url: URL) {
    network.withLock { _ = $0.held.remove(url) }
  }

  private static func isHeld(_ url: URL) -> Bool {
    network.withLock { $0.held.contains(url) }
  }

  private static func answer(for url: URL) -> StubResponse? {
    network.withLock {
      $0.requested.append(url)
      return $0.responses[url]
    }
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url else { return fail(.badURL) }
    guard let stub = Self.answer(for: url) else { return fail(.cannotFindHost) }
    waitForRelease(of: url, then: stub)
  }

  private func waitForRelease(of url: URL, then stub: StubResponse) {
    guard !Self.isHeld(url) else {
      nonisolated(unsafe) let waiting = self
      DispatchQueue.global().asyncAfter(deadline: .now() + Self.holdPollInterval) {
        waiting.waitForRelease(of: url, then: stub)
      }
      return
    }
    respond(to: url, with: stub)
  }

  private func respond(to url: URL, with stub: StubResponse) {
    if let code = stub.failure { return fail(code) }
    guard
      let response = HTTPURLResponse(
        url: url, statusCode: stub.status, httpVersion: "HTTP/1.1", headerFields: nil)
    else { return fail(.badServerResponse) }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    if !stub.body.isEmpty { client?.urlProtocol(self, didLoad: stub.body) }
    if !stub.staysOpen { client?.urlProtocolDidFinishLoading(self) }
  }

  override func stopLoading() {}

  private func fail(_ code: URLError.Code) {
    client?.urlProtocol(self, didFailWithError: URLError(code))
  }
}
