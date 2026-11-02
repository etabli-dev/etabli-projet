import Foundation
@main struct CheckClient {
    @MainActor static func main() async throws {
        let domain = "etabli-client-test-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let client = OPClient(session: fixtureSession(), defaults: defaults)
        FixtureProtocol.replies = [(200, #"{"id":7,"name":"User"}"#)]
        let me = try await client.configure(baseURL: URL(string: "https://fixture.invalid/project")!, token: "secret")
        precondition(me.id == 7)
        precondition(FixtureProtocol.requests.last!.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        FixtureProtocol.replies = [(200, #"{"_embedded":{"elements":[{"id":3,"name":"Project"}]}}"#)]
        let projects = try await client.listProjects()
        precondition(projects.first?.id == 3)
        precondition(FixtureProtocol.requests.last!.url!.query == "pageSize=200")
        let before = client.config
        FixtureProtocol.replies = [(401, "{}"), (401, "{}")]
        do { try await client.configure(baseURL: URL(string: "https://wrong.invalid")!, token: "bad"); fatalError("Bad account accepted") } catch { precondition(client.config == before) }
        FixtureProtocol.replies = [(409, "{}")]
        do { _ = try await client.updateSubject(id: 9, lockVersion: 1, newSubject: "Changed"); fatalError("Conflict hidden") } catch OPError.versionConflict { }
        let restored = OPClient(session: fixtureSession(), defaults: defaults)
        precondition(restored.config?.baseURL == before?.baseURL)
        try await checkAuthenticationCompatibility()
        try await checkTransportBounds()
        print("OpenProject client: identity, HAL list, failed account preservation, optimistic conflict and restore passed")
    }
}

@MainActor
func checkAuthenticationCompatibility() async throws {
    let domain = "etabli-auth-test-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    defer {
        defaults.removePersistentDomain(forName: domain)
        FixtureProtocol.requestHandler = nil
        Keychain.values.removeAll()
    }
    Keychain.values.removeAll()
    let base = URL(string: "https://fixture.invalid/openproject")!
    let basic = "Basic " + Data("apikey:legacy-key".utf8).base64EncodedString()
    let me = #"{"id":7,"name":"User"}"#
    let projects = #"{"_embedded":{"elements":[{"id":3,"name":"Project"}]}}"#
    FixtureProtocol.requests = []
    FixtureProtocol.requestHandler = { request in
        request.value(forHTTPHeaderField: "Authorization") == "Bearer opapi-current" ? (200, me) : (401, "{}")
    }
    let client = OPClient(session: fixtureSession(), defaults: defaults)
    _ = try await client.configure(baseURL: base, token: "opapi-current")
    precondition(FixtureProtocol.requests.count == 1)
    FixtureProtocol.requests = []
    FixtureProtocol.requestHandler = { request in
        guard request.value(forHTTPHeaderField: "Authorization") == basic else {
            Thread.sleep(forTimeInterval: 0.03)
            return (401, "{}")
        }
        if request.httpMethod == "PATCH" { return (401, "{}") }
        return (200, request.url!.path.hasSuffix("/projects") ? projects : me)
    }
    let identity = try await client.configure(baseURL: base, token: "legacy-key")
    precondition(identity.id == 7)
    let attempts = FixtureProtocol.requests
    precondition(attempts.count == 2)
    precondition(attempts[0].value(forHTTPHeaderField: "Authorization") == "Bearer legacy-key")
    precondition(attempts[1].value(forHTTPHeaderField: "Authorization") == basic)
    precondition(attempts.allSatisfy { $0.httpMethod == "GET" && $0.url?.absoluteString == "https://fixture.invalid/openproject/api/v3/users/me" })
    precondition(attempts[1].timeoutInterval < attempts[0].timeoutInterval && attempts[0].timeoutInterval <= 45)

    let saved = Keychain.values
    let stored = try JSONDecoder().decode(StoredConnection.self,
        from: Data(saved["projectviewer.openproject:connection.v2"]!.utf8))
    precondition(stored.authentication == .basic)
    let restored = OPClient(session: fixtureSession(), defaults: defaults)
    let rows = try await restored.listProjects()
    precondition(rows.first?.id == 3)
    precondition(FixtureProtocol.requests.last!.value(forHTTPHeaderField: "Authorization") == basic)
    let beforeWrite = FixtureProtocol.requests.count
    do { _ = try await restored.updateSubject(id: 9, lockVersion: 1, newSubject: "Changed"); fatalError("Unauthorized mutation accepted") }
    catch OPError.http(status: 401, body: _) { }
    precondition(FixtureProtocol.requests.count == beforeWrite + 1)
    precondition(FixtureProtocol.requests.last!.value(forHTTPHeaderField: "Authorization") == basic)

    Keychain.failWrite = true
    do { _ = try await client.configure(baseURL: base, token: "legacy-key"); fatalError("Secure-store failure ignored") }
    catch is ClientHTTPError { }
    Keychain.failWrite = false
    precondition(Keychain.values == saved)

    for status in [401, 403, 307, 500, 200] {
        FixtureProtocol.requestHandler = { _ in (status, "{}") }
        let start = FixtureProtocol.requests.count
        do { _ = try await client.configure(baseURL: base, token: "bad"); fatalError("Invalid candidate accepted") }
        catch { }
        precondition(FixtureProtocol.requests.count - start == (status == 401 ? 2 : 1))
        precondition(Keychain.values == saved)
    }
    FixtureProtocol.requestHandler = nil
    FixtureProtocol.replies = []
    let transportStart = FixtureProtocol.requests.count
    do { _ = try await client.configure(baseURL: base, token: "bad"); fatalError("Transport failure ignored") }
    catch { }
    precondition(FixtureProtocol.requests.count == transportStart + 1 && Keychain.values == saved)

    // Existing envelopes and the older separate-key format both keep Bearer.
    let legacy = #"{"server":"https://fixture.invalid/openproject","token":"existing-token"}"#
    Keychain.values = ["projectviewer.openproject:connection.v2": legacy]
    FixtureProtocol.requestHandler = { request in
        request.value(forHTTPHeaderField: "Authorization") == "Bearer existing-token" ? (200, me) : (401, "{}")
    }
    let envelope = OPClient(session: fixtureSession(), defaults: defaults)
    _ = try await envelope.testConnection()
    Keychain.values = ["projectviewer.openproject:token": "existing-token"]
    defaults.set(base, forKey: "projectviewer.openproject.baseurl")
    let separate = OPClient(session: fixtureSession(), defaults: defaults)
    _ = try await separate.testConnection()

    // Hold a successful fallback while Disconnect invalidates the connection intent.
    let arrived = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    FixtureProtocol.requestHandler = { request in
        if request.value(forHTTPHeaderField: "Authorization")!.hasPrefix("Bearer ") { return (401, "{}") }
        arrived.signal()
        precondition(release.wait(timeout: .now() + 5) == .success)
        return (200, me)
    }
    let pending = Task { try await separate.configure(baseURL: base, token: "legacy-key") }
    let observed = await withCheckedContinuation { continuation in
        DispatchQueue.global().async { continuation.resume(returning: arrived.wait(timeout: .now() + 3) == .success) }
    }
    precondition(observed)
    try separate.disconnect()
    release.signal()
    do { _ = try await pending.value; fatalError("Disconnected account restored by fallback") }
    catch is CancellationError { }
    precondition(Keychain.values.isEmpty && separate.config == nil)
    print("OpenProject authentication: Basic-only handshake, shared deadline, mode restore, old Bearer records, failure preservation, bounded retries, single PATCH and disconnect passed")
}
