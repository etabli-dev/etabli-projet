// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0
import Foundation

enum ClientHTTPError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
enum OPAuthentication: String, Codable {
    case bearer, basic

    func authorization(_ token: String) -> String {
        switch self {
        case .bearer: return "Bearer \(token)"
        case .basic: return "Basic " + Data("apikey:\(token)".utf8).base64EncodedString()
        }
    }
}

struct StoredConnection: Codable {
    let server: URL
    let token: String
    // Existing envelopes have no mode and retain their Bearer behavior.
    var authentication: OPAuthentication? = nil
    var effectiveAuthentication: OPAuthentication { authentication ?? .bearer }
}

func secureServer(_ url: URL) throws -> URL {
    guard url.scheme?.lowercased() == "https", url.host?.isEmpty == false,
          url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
        throw ClientHTTPError.invalid("Use an HTTPS server URL without credentials, query or fragment")
    }
    return URL(string: url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")))!
}

final class ClientHTTP: @unchecked Sendable {
    private let configuration: URLSessionConfiguration
    init(configuration: URLSessionConfiguration) { self.configuration = configuration }
    private func prepare(_ request: URLRequest) throws -> URLRequest {
        try Task.checkCancellation()
        guard let url = request.url, url.scheme?.lowercased() == "https", url.user == nil, url.password == nil else {
            throw ClientHTTPError.invalid("Authenticated requests require HTTPS")
        }
        var copy = request; copy.timeoutInterval = min(request.timeoutInterval, 45)
        return copy
    }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await ClientTransfer(limit: 8 * 1024 * 1024, configuration: configuration).run(prepare(request))
    }
    func download(for request: URLRequest) async throws -> (URL, URLResponse) {
        let prepared = try prepare(request)
        let target = FileManager.default.temporaryDirectory.appendingPathComponent("etabli-download-" + UUID().uuidString)
        try Data().write(to: target, options: .withoutOverwriting)
        do {
            let sink = try FileHandle(forWritingTo: target)
            let (_, response) = try await ClientTransfer(limit: 256 * 1024 * 1024, configuration: configuration, sink: sink).run(prepared)
            return (target, response)
        } catch { try? FileManager.default.removeItem(at: target); throw error }
    }
}

private final class ClientTransfer: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let limit: Int
    private let configuration: URLSessionConfiguration
    private let sink: FileHandle?
    private var count = 0
    private var continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>?
    private var completed: Result<(Data, HTTPURLResponse), Error>?
    private var response: HTTPURLResponse?
    private var body = Data()
    private var session: URLSession?
    init(limit: Int, configuration: URLSessionConfiguration, sink: FileHandle? = nil) { self.limit = limit; self.configuration = configuration; self.sink = sink }
    func run(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if let completed { lock.unlock(); continuation.resume(with: completed); return }
                self.continuation = continuation
                let config = configuration.copy() as! URLSessionConfiguration
                config.timeoutIntervalForRequest = request.timeoutInterval
                config.timeoutIntervalForResource = request.timeoutInterval
                config.requestCachePolicy = .reloadIgnoringLocalCacheData
                config.httpCookieStorage = nil
                config.urlCredentialStorage = nil
                config.urlCache = nil
                let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
                let session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
                self.session = session
                let task = session.dataTask(with: request)
                lock.unlock()
                task.resume()
            }
        } onCancel: { self.finish(.failure(CancellationError())) }
    }
    private func finish(_ result: Result<(Data, HTTPURLResponse), Error>) {
        lock.lock()
        guard completed == nil else { lock.unlock(); return }
        var finalResult = result
        do {
            if case .success = result { try sink?.synchronize() }
            try sink?.close()
        } catch { finalResult = .failure(error) }
        completed = finalResult
        let pending = continuation; continuation = nil
        let currentSession = session; session = nil
        lock.unlock()
        currentSession?.invalidateAndCancel()
        pending?.resume(with: finalResult)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.cancel); finish(.failure(URLError(.badServerResponse))); return
        }
        if response.expectedContentLength > limit {
            completionHandler(.cancel); finish(.failure(ClientHTTPError.invalid("Response exceeds allowed size"))); return
        }
        lock.lock(); self.response = http; lock.unlock()
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard completed == nil else { lock.unlock(); return }
        if data.count > limit - count {
            lock.unlock(); finish(.failure(ClientHTTPError.invalid("Response exceeds allowed size"))); return
        }
        do {
            if let sink { try sink.write(contentsOf: data) } else { body.append(data) }
            count += data.count
            lock.unlock()
        } catch { lock.unlock(); finish(.failure(error)) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish(.failure(error)); return }
        lock.lock(); let response = response; let body = body; lock.unlock()
        if let response { finish(.success((body, response))) }
        else { finish(.failure(URLError(.badServerResponse))) }
    }
}
