import Foundation

// Compiled instead of the platform wrapper, so checks never touch a real Keychain.
enum Keychain {
    static var values: [String: String] = [:]
    static var failWrite = false
    static func get(service: String, account: String) throws -> String? { values[service + ":" + account] }
    static func set(_ value: String, service: String, account: String) throws {
        if failWrite { throw ClientHTTPError.invalid("Simulated secure-store failure") }
        values[service + ":" + account] = value
    }
    static func delete(service: String, account: String) throws { values.removeValue(forKey: service + ":" + account) }
}
final class FixtureProtocol: URLProtocol, @unchecked Sendable {
    static var replies: [(Int, String)] = []
    static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        guard !Self.replies.isEmpty else { client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return }
        let (status, body) = Self.replies.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json", "Content-Length": String(body.utf8.count)])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
func fixtureSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [FixtureProtocol.self]
    return URLSession(configuration: config)
}

func checkTransportBounds() async throws {
    let transport = ClientHTTP(configuration: fixtureSession().configuration)
    let request = URLRequest(url: URL(string: "https://fixture.invalid/oversized")!)
    FixtureProtocol.replies = [(200, String(repeating: "x", count: 8 * 1024 * 1024 + 1))]
    do { _ = try await transport.data(for: request); fatalError("Oversized JSON response accepted") }
    catch let error as ClientHTTPError { precondition(error.localizedDescription.contains("size")) }
    do { _ = try await transport.data(for: URLRequest(url: URL(string: "http://fixture.invalid")!)); fatalError("Plaintext transport allowed") }
    catch is ClientHTTPError { }
}
