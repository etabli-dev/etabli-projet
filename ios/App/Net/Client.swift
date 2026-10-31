// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation

// OpenProject HTTP client.
//
// Auth: a single long-lived API token sent as `Authorization: Bearer <token>`.
// (OpenProject also accepts Basic with username "apikey" + token as password;
// Bearer is simpler and what the docs recommend for personal API access.)
//
// Spec verification:
//   - openproject.org/docs/api      → human spec
//   - <baseURL>/api/v3/spec.json    → machine spec on the live instance
//   We assume v3, send HAL JSON, and verify the live `/users/me` on connect.

public struct OPConfig: Equatable, Sendable {
    public var baseURL: URL
    public var hasToken: Bool       // we never expose the token via @Observable
    public init(baseURL: URL, hasToken: Bool) {
        self.baseURL = baseURL; self.hasToken = hasToken
    }
}

public enum OPError: Error, LocalizedError {
    case notConfigured
    case http(status: Int, body: String?)
    case decoding(String)
    case transport(String)
    case versionConflict
    public var errorDescription: String? {
        switch self {
        case .notConfigured:  "Set the base URL + API token in Settings."
        case .http(let s, _): "Server returned HTTP \(s)."
        case .decoding(let m): "Couldn't decode response: \(m)."
        case .transport(let m): "Network error: \(m)."
        case .versionConflict: "Item changed on the server — refresh and retry."
        }
    }
}

@MainActor
@Observable
public final class OPClient {

    public private(set) var config: OPConfig?

    private let session: ClientHTTP
    private let defaults: UserDefaults
    private var connectionIntent = UUID()
    private let decoder: JSONDecoder
    private let keychainService = "projectviewer.openproject"
    private let urlKey = "projectviewer.openproject.baseurl"

    public init(session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.session = ClientHTTP(configuration: session.configuration)
        self.defaults = defaults
        self.decoder = JSONDecoder()

        // Restore the (URL, has-token) pair on launch. Token stays in
        // Keychain; the URL is non-secret config. `Keychain.get` returns
        // `String?`, and `try?` wraps that, so we flatten with `?? nil`.
        if let saved = (try? Keychain.get(service: keychainService, account: "connection.v2")) ?? nil {
            guard let value = try? JSONDecoder().decode(StoredConnection.self, from: Data(saved.utf8)),
                  (try? secureServer(value.server)) != nil, !value.token.isEmpty else { return }
            self.config = OPConfig(baseURL: value.server, hasToken: true)
            return
        }
        if let stored = defaults.url(forKey: urlKey), (try? secureServer(stored)) != nil,
           let token = (try? Keychain.get(service: keychainService, account: "token")) ?? nil,
           !token.isEmpty {
            self.config = OPConfig(baseURL: stored, hasToken: true)
        }
    }

    // MARK: - Setup

    @discardableResult
    public func configure(baseURL: URL, token: String) async throws -> OPMe {
        let intent = UUID(); connectionIntent = intent
        let baseURL = try secureServer(baseURL)
        guard !token.isEmpty else { throw OPError.notConfigured }
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v3/users/me"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/hal+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try Self.checkResponse(response, data: data)
        let me = try decoder.decode(OPMe.self, from: data)
        guard connectionIntent == intent else { throw CancellationError() }
        let saved = try JSONEncoder().encode(StoredConnection(server: baseURL, token: token))
        try Keychain.set(String(decoding: saved, as: UTF8.self), service: keychainService, account: "connection.v2")
        defaults.set(baseURL, forKey: urlKey)
        config = OPConfig(baseURL: baseURL, hasToken: true)
        return me
    }

    public func disconnect() throws {
        connectionIntent = UUID()
        try Keychain.delete(service: keychainService, account: "token")
        try Keychain.delete(service: keychainService, account: "connection.v2")
        defaults.removeObject(forKey: urlKey)
        config = nil
    }

    private func token() throws -> String {
        if let saved = try Keychain.get(service: keychainService, account: "connection.v2") {
            let value = try JSONDecoder().decode(StoredConnection.self, from: Data(saved.utf8))
            guard value.server == config?.baseURL else { throw OPError.notConfigured }
            return value.token
        }
        guard let t = try Keychain.get(service: keychainService, account: "token"), !t.isEmpty
        else { throw OPError.notConfigured }
        return t
    }

    // MARK: - Endpoints

    public func testConnection() async throws -> OPMe {
        try await getDecoded("/api/v3/users/me", as: OPMe.self)
    }

    public func listProjects() async throws -> [OPProject] {
        let coll: HALCollection<OPProject> = try await getDecoded(
            "/api/v3/projects?pageSize=200", as: HALCollection<OPProject>.self
        )
        return coll.elements
    }

    public struct WorkPackagePage: Sendable {
        public let workPackages: [OPWorkPackage]
        public let total: Int
        public let nextOffsetPath: String?
    }

    /// `assignedToMe` filters using OpenProject's JSON filter syntax —
    /// `[{"assignee":{"operator":"=","values":["me"]}}]` per the API docs.
    public func listWorkPackages(projectID: Int? = nil,
                                 assignedToMe: Bool = false,
                                 query: String? = nil,
                                 offset: Int = 1,
                                 pageSize: Int = 50) async throws -> WorkPackagePage {
        var path = projectID.map { "/api/v3/projects/\($0)/work_packages" } ?? "/api/v3/work_packages"
        var items = [URLQueryItem(name: "pageSize", value: String(pageSize)),
                     URLQueryItem(name: "offset", value: String(offset))]
        var filters: [[String: Any]] = []
        if assignedToMe {
            filters.append(["assignee": ["operator": "=", "values": ["me"]]])
        }
        if let q = query?.trimmingCharacters(in: .whitespaces), !q.isEmpty {
            filters.append(["search": ["operator": "**", "values": [q]]])
        }
        if !filters.isEmpty,
           let data = try? JSONSerialization.data(withJSONObject: filters),
           let s = String(data: data, encoding: .utf8) {
            items.append(URLQueryItem(name: "filters", value: s))
        }
        var comps = URLComponents()
        comps.path = path
        comps.queryItems = items
        if let q = comps.percentEncodedQuery { path += "?\(q)" }

        let coll: HALCollection<OPWorkPackage> = try await getDecoded(path, as: HALCollection<OPWorkPackage>.self)
        return WorkPackagePage(
            workPackages: coll.elements,
            total: coll.total ?? coll.elements.count,
            nextOffsetPath: coll._links?.nextByOffset?.href
        )
    }

    public func fetchWorkPackage(id: Int) async throws -> OPWorkPackage {
        try await getDecoded("/api/v3/work_packages/\(id)", as: OPWorkPackage.self)
    }

    /// PATCH a work package's subject. Sends the current `lockVersion`
    /// for optimistic concurrency. On 409 we throw `.versionConflict` so
    /// the UI can re-fetch and ask the user to retry.
    public func updateSubject(id: Int, lockVersion: Int, newSubject: String) async throws -> OPWorkPackage {
        let body: [String: Any] = [
            "lockVersion": lockVersion,
            "subject": newSubject
        ]
        return try await patch("/api/v3/work_packages/\(id)", body: body, as: OPWorkPackage.self)
    }

    // MARK: - Generic transport

    private func authorizedRequest(path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let cfg = config else { throw OPError.notConfigured }
        // `appendingPathComponent` URL-encodes `?`, which kills query
        // strings. Build URL by string concatenation against the base —
        // simpler than juggling URLComponents.
        let trimmedBase = cfg.baseURL.absoluteString.hasSuffix("/")
            ? String(cfg.baseURL.absoluteString.dropLast())
            : cfg.baseURL.absoluteString
        let separator = path.hasPrefix("/") ? "" : "/"
        guard let full = URL(string: trimmedBase + separator + path) else {
            throw OPError.transport("Couldn't build URL from \(trimmedBase)\(separator)\(path)")
        }
        var req = URLRequest(url: full)
        req.httpMethod = method
        req.setValue("Bearer \(try token())", forHTTPHeaderField: "Authorization")
        req.setValue("application/hal+json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return req
    }

    private func getDecoded<T: Decodable>(_ path: String, as: T.Type) async throws -> T {
        let req = try authorizedRequest(path: path)
        do {
            let (data, response) = try await session.data(for: req)
            try Self.checkResponse(response, data: data)
            do { return try decoder.decode(T.self, from: data) }
            catch { throw OPError.decoding(error.localizedDescription) }
        } catch is CancellationError { throw CancellationError() }
        catch let e as OPError { throw e }
        catch { throw OPError.transport(error.localizedDescription) }
    }

    private func patch<T: Decodable>(_ path: String, body: [String: Any], as: T.Type) async throws -> T {
        let data = try JSONSerialization.data(withJSONObject: body, options: [])
        let req = try authorizedRequest(path: path, method: "PATCH", body: data)
        do {
            let (respData, response) = try await session.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 409 {
                throw OPError.versionConflict
            }
            try Self.checkResponse(response, data: respData)
            do { return try decoder.decode(T.self, from: respData) }
            catch { throw OPError.decoding(error.localizedDescription) }
        } catch is CancellationError { throw CancellationError() }
        catch let e as OPError { throw e }
        catch { throw OPError.transport(error.localizedDescription) }
    }

    private static func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw OPError.transport("No HTTP response") }
        guard (200..<300).contains(http.statusCode) else {
            throw OPError.http(status: http.statusCode,
                               body: String(data: data, encoding: .utf8))
        }
    }
}
