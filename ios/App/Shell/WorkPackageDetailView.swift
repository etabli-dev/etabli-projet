// Copyright 2026 Raban Heller
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

struct WorkPackageDetailView: View {
    let workPackage: OPWorkPackage
    var onUpdated: (OPWorkPackage?) -> Void = { _ in }

    @Environment(OPClient.self) private var client
    @Environment(\.dismiss) private var dismiss
    @State private var wp: OPWorkPackage
    @State private var subject: String = ""
    @State private var saving = false
    @State private var error: String?
    @State private var info: String?

    init(workPackage: OPWorkPackage, onUpdated: @escaping (OPWorkPackage?) -> Void = { _ in }) {
        self.workPackage = workPackage
        self._wp = State(initialValue: workPackage)
        self.onUpdated = onUpdated
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.lg) {
                        header
                        if let info { StatusLabel(info, tone: .accent) }
                        if let error {
                            Text(error).font(Theme.Font.body).foregroundStyle(Theme.Color.danger)
                        }
                        subjectCard
                        metaCard
                        descriptionCard
                    }.padding(Theme.Space.lg)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.font(Theme.Font.mono)
                }
            }
            .onAppear { subject = wp.subject ?? "" }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            MonoLabel("WP #\(wp.id)", color: Theme.Color.faint)
            Text(wp.subject ?? "(no subject)")
                .font(Theme.Font.display).foregroundStyle(Theme.Color.ink)
        }
    }

    private var subjectCard: some View {
        Card(title: "subject", systemImage: "text.alignleft") {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                TextField("subject", text: $subject)
                    .textFieldStyle(.plain)
                    .font(Theme.Font.monoBody).foregroundStyle(Theme.Color.ink)
                    .padding(Theme.Space.sm).background(Theme.Color.paper)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .strokeBorder(Theme.Color.hairline, lineWidth: 1))
                PrimaryButton(saving ? "Saving…" : "Save subject", systemImage: "checkmark.seal",
                              enabled: !saving && subject != (wp.subject ?? "")) {
                    Task { await save() }
                }
            }
        }
    }

    private var metaCard: some View {
        Card(title: "metadata", systemImage: "info.circle") {
            VStack(spacing: Theme.Space.xs) {
                row("project", wp.projectName)
                row("status", wp.statusName)
                row("type", wp.typeName)
                row("priority", wp.priorityName)
                row("assignee", wp.assigneeName)
                row("lockVersion", wp.lockVersion.map(String.init))
            }
        }
    }

    private var descriptionCard: some View {
        Card(title: "description", systemImage: "doc.text") {
            if let raw = wp.description?.raw, !raw.isEmpty {
                Text(raw).font(Theme.Font.mono).foregroundStyle(Theme.Color.ink)
                    .textSelection(.enabled)
            } else {
                MonoLabel("(no description)", color: Theme.Color.faint)
            }
        }
    }

    private func row(_ key: String, _ value: String?) -> some View {
        HStack {
            MonoLabel(key, color: Theme.Color.faint)
            Spacer()
            MonoLabel(value ?? "—")
        }
    }

    private func save() async {
        guard let lockVersion = wp.lockVersion else {
            error = "Server didn't return a lockVersion; can't safely patch."
            return
        }
        saving = true; error = nil; info = nil
        defer { saving = false }
        do {
            let updated = try await client.updateSubject(id: wp.id,
                                                        lockVersion: lockVersion,
                                                        newSubject: subject)
            wp = updated
            onUpdated(updated)
            info = "Saved."
        } catch OPError.versionConflict {
            // Re-fetch and let the user retry from a clean lockVersion.
            info = "This work package was changed elsewhere — refreshed to latest."
            do {
                let fresh = try await client.fetchWorkPackage(id: wp.id)
                wp = fresh
                subject = fresh.subject ?? ""
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
