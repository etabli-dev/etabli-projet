// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

struct MyWorkView: View {
    @Environment(OPClient.self) private var client
    @State private var workPackages: [OPWorkPackage] = []
    @State private var loading = false
    @State private var error: String?
    @State private var selected: OPWorkPackage?

    var body: some View {
        ZStack {
            Theme.Color.paper.ignoresSafeArea()
            content
        }
        .toolbar(.hidden, for: .navigationBar)
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

    @ViewBuilder
    private var content: some View {
        if client.config == nil {
            EmptyState(title: "not connected", detail: "Open Settings to connect to your OpenProject.",
                       systemImage: "link.badge.plus")
        } else if loading && workPackages.isEmpty {
            LoadingState("fetching assigned work…")
        } else if let error, workPackages.isEmpty {
            ErrorState(title: "couldn't fetch", detail: error, retry: { Task { await load() } })
        } else if workPackages.isEmpty {
            EmptyState(title: "nothing assigned to you", systemImage: "checkmark.seal")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    PromptHeader(["my-work"])
                    Text("Assigned to me")
                        .font(Theme.Font.display).foregroundStyle(Theme.Color.ink)
                    list
                }.padding(Theme.Space.lg)
            }
        }
    }

    private var list: some View {
        Card(title: "\(workPackages.count) work packages", systemImage: "tray.full") {
            VStack(spacing: 0) {
                ForEach(workPackages) { wp in
                    Button { selected = wp } label: {
                        ListRow(
                            title: wp.subject ?? "(no subject)",
                            metadata: subtitle(wp),
                            leading: { statusGlyph(wp) },
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

    private func subtitle(_ wp: OPWorkPackage) -> String {
        [wp.projectName, wp.statusName, wp.typeName].compactMap { $0 }.joined(separator: " · ")
    }
    private func statusGlyph(_ wp: OPWorkPackage) -> some View {
        let name = (wp.statusName ?? "").lowercased()
        let symbol: String = {
            switch name {
            case "closed", "done":  "checkmark.circle.fill"
            case "in progress":     "circle.dotted"
            case "rejected":        "xmark.circle"
            default:                "circle"
            }
        }()
        return Image(systemName: symbol).foregroundStyle(Theme.Color.accent)
    }

    private func load() async {
        guard client.config != nil else { return }
        loading = true; error = nil
        do {
            let page = try await client.listWorkPackages(assignedToMe: true, pageSize: 100)
            workPackages = page.workPackages
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }
}
