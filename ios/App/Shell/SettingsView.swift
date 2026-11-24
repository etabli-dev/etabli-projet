// Copyright 2026 R. Heller
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

struct SettingsView: View {
    @Environment(OPClient.self) private var client

    @State private var urlText: String = ""
    @State private var token: String = ""
    @State private var testing = false
    @State private var testResult: String?
    @State private var testError: String?

    var body: some View {
        ZStack {
            Theme.Color.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    PromptHeader(["settings"])
                    Text("Connection")
                        .font(Theme.Font.display).foregroundStyle(Theme.Color.ink)
                    if let cfg = client.config {
                        connectedCard(cfg)
                    } else {
                        connectCard
                    }
                    AppearanceCard()
                    aboutCard
                }.padding(Theme.Space.lg).readableColumn()
            }
        }
        .navigationBarHidden(true)
    }

    private var connectCard: some View {
        Card(title: "connect to openproject", systemImage: "link") {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                Text("Paste your OpenProject base URL and a personal API token (create one in OpenProject under My Account → Access Tokens).")
                    .font(Theme.Font.body).foregroundStyle(Theme.Color.ink)
                field("base URL", text: $urlText, placeholder: "https://openproject.example.com")
                field("API token", text: $token, placeholder: "paste token", secure: true)
                MonoLabel("Stored in the iOS Keychain. Never logged.", color: Theme.Color.faint)
                if let testError {
                    Text(testError).font(Theme.Font.body).foregroundStyle(Theme.Color.danger)
                }
                HStack(spacing: Theme.Space.md) {
                    PrimaryButton(testing ? "Connecting…" : "Connect", systemImage: "checkmark.seal",
                                  enabled: !urlText.isEmpty && !token.isEmpty && !testing) {
                        connect()
                    }
                }
            }
        }
    }

    private func connectedCard(_ cfg: OPConfig) -> some View {
        Card(title: "connected", systemImage: "checkmark.circle") {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                MonoLabel(cfg.baseURL.absoluteString, color: Theme.Color.ink)
                if let testResult {
                    StatusLabel(testResult, tone: .success)
                }
                if let testError {
                    Text(testError).font(Theme.Font.body).foregroundStyle(Theme.Color.danger)
                }
                HStack(spacing: Theme.Space.md) {
                    PrimaryButton(testing ? "Testing…" : "Test connection", systemImage: "arrow.triangle.2.circlepath",
                                  enabled: !testing) {
                        Task { await test() }
                    }
                    Button(role: .destructive) {
                        do { try client.disconnect(); testResult = nil; testError = nil }
                        catch { testError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
                    } label: {
                        Text("Disconnect").font(Theme.Font.body.weight(.semibold))
                            .padding(.horizontal, Theme.Space.md).padding(.vertical, Theme.Space.sm)
                            .foregroundStyle(Theme.Color.onAccent)
                            .background(Theme.Color.danger)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var aboutCard: some View {
        Card(title: "about", systemImage: "info.circle") {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("EtabliProjet").font(Theme.Font.headline).foregroundStyle(Theme.Color.ink)
                Text("OpenProject companion. HAL+JSON, optimistic locking, offline-first work-package cache. No analytics; no tracking.")
                    .font(Theme.Font.body).foregroundStyle(Theme.Color.faint)
            }
        }
    }

    @ViewBuilder
    private func field(_ label: LocalizedStringKey, text: Binding<String>, placeholder: LocalizedStringKey,
                       secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            MonoLabel(label, color: Theme.Color.faint)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textFieldStyle(.plain)
            .font(Theme.Font.monoBody).foregroundStyle(Theme.Color.ink)
            .padding(Theme.Space.sm).background(Theme.Color.paper)
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .strokeBorder(Theme.Color.hairline, lineWidth: 1))
            .autocorrectionDisabled().textInputAutocapitalization(.never)
        }
    }

    private func connect() {
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespaces)) else {
            testError = String(localized: "Invalid URL"); return
        }
        testing = true; testError = nil; testResult = nil
        Task {
            do {
                let me = try await client.configure(baseURL: url, token: token.trimmingCharacters(in: .whitespaces))
                token = ""
                testResult = String(localized: "Signed in as \(me.name ?? String(localized: "user \(me.id)"))")
            } catch {
                testError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            testing = false
        }
    }

    private func test() async {
        testing = true; testError = nil
        do {
            let me = try await client.testConnection()
            testResult = String(localized: "Signed in as \(me.name ?? String(localized: "user \(me.id)"))")
        } catch {
            testError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        testing = false
    }
}
