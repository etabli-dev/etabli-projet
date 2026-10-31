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
        FixtureProtocol.replies = [(401, "{}")]
        do { try await client.configure(baseURL: URL(string: "https://wrong.invalid")!, token: "bad"); fatalError("Bad account accepted") } catch { precondition(client.config == before) }
        FixtureProtocol.replies = [(409, "{}")]
        do { _ = try await client.updateSubject(id: 9, lockVersion: 1, newSubject: "Changed"); fatalError("Conflict hidden") } catch OPError.versionConflict { }
        let restored = OPClient(session: fixtureSession(), defaults: defaults)
        precondition(restored.config?.baseURL == before?.baseURL)
        try await checkTransportBounds()
        print("OpenProject client: identity, HAL list, failed account preservation, optimistic conflict and restore passed")
    }
}
