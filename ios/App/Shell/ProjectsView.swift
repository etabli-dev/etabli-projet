// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

struct ProjectsView: View {
    @Environment(OPClient.self) private var client
    @State private var projects: [OPProject] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Theme.Color.paper.ignoresSafeArea()
            content
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if client.config == nil {
            EmptyState(title: "not connected", detail: "Open Settings to connect.",
                       systemImage: "link.badge.plus")
        } else if loading && projects.isEmpty {
            LoadingState("fetching projects…")
        } else if let error, projects.isEmpty {
            ErrorState(title: "couldn't fetch", detail: error, retry: { Task { await load() } })
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    PromptHeader(["projects"])
                    Text("Projects")
                        .font(Theme.Font.display).foregroundStyle(Theme.Color.ink)
                    Card(title: "\(projects.count) projects", systemImage: "rectangle.stack") {
                        VStack(spacing: 0) {
                            ForEach(projects) { p in
                                NavigationLink {
                                    ProjectWorkPackagesView(project: p)
                                } label: {
                                    ListRow(
                                        title: p.name ?? "(unnamed)",
                                        metadata: p.identifier,
                                        leading: { Image(systemName: "folder").foregroundStyle(Theme.Color.accent) },
                                        trailing: {
                                            Image(systemName: "chevron.right")
                                                .font(Theme.Font.mono).foregroundStyle(Theme.Color.faint)
                                        }
                                    )
                                }.buttonStyle(.plain)
                                if p.id != projects.last?.id {
                                    Divider().background(Theme.Color.hairline)
                                }
                            }
                        }
                    }
                }.padding(Theme.Space.lg)
            }
        }
    }

    private func load() async {
        guard client.config != nil else { return }
        loading = true; error = nil
        do { projects = try await client.listProjects() }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
        loading = false
    }
}

struct ProjectWorkPackagesView: View {
    let project: OPProject
    @Environment(OPClient.self) private var client
    @State private var workPackages: [OPWorkPackage] = []
    @State private var loading = false
    @State private var error: String?
    @State private var query = ""
    @State private var selected: OPWorkPackage?

    var body: some View {
        ZStack {
            Theme.Color.paper.ignoresSafeArea()
            content
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $selected) { wp in
            WorkPackageDetailView(workPackage: wp) { updated in
                if let updated, let idx = workPackages.firstIndex(where: { $0.id == updated.id }) {
                    workPackages[idx] = updated
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                PromptHeader(["projects", project.identifier ?? "\(project.id)"])
                Text(project.name ?? "(unnamed)")
                    .font(Theme.Font.display).foregroundStyle(Theme.Color.ink)
                searchBar
                if loading && workPackages.isEmpty {
                    LoadingState("fetching work packages…").frame(height: 240)
                } else if let error, workPackages.isEmpty {
                    ErrorState(title: "couldn't fetch", detail: error, retry: { Task { await load() } })
                        .frame(height: 240)
                } else if workPackages.isEmpty {
                    EmptyState(title: "no work packages", systemImage: "tray").frame(height: 240)
                } else {
                    Card(title: "\(workPackages.count) work packages", systemImage: "list.bullet") {
                        VStack(spacing: 0) {
                            ForEach(workPackages) { wp in
                                Button { selected = wp } label: {
                                    ListRow(
                                        title: wp.subject ?? "(no subject)",
                                        metadata: [wp.statusName, wp.typeName].compactMap { $0 }.joined(separator: " · "),
                                        leading: { Image(systemName: "doc").foregroundStyle(Theme.Color.accent) },
                                        trailing: {
                                            Image(systemName: "chevron.right")
                                                .font(Theme.Font.mono).foregroundStyle(Theme.Color.faint)
                                        }
                                    )
                                }.buttonStyle(.plain)
                                if wp.id != workPackages.last?.id {
                                    Divider().background(Theme.Color.hairline)
                                }
                            }
                        }
                    }
                }
            }.padding(Theme.Space.lg)
        }
    }

    private var searchBar: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.Color.faint)
            TextField("filter by subject", text: $query)
                .textFieldStyle(.plain)
                .font(Theme.Font.monoBody).foregroundStyle(Theme.Color.ink)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .onSubmit { Task { await load() } }
        }
        .padding(Theme.Space.sm)
        .background(Theme.Color.surface)
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm)
            .strokeBorder(Theme.Color.hairline, lineWidth: 1))
    }

    private func load() async {
        loading = true; error = nil
        do {
            let page = try await client.listWorkPackages(projectID: project.id,
                                                         query: query.isEmpty ? nil : query,
                                                         pageSize: 100)
            workPackages = page.workPackages
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }
}
