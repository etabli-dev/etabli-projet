// Copyright 2026 Raban Heller
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

struct RootView: View {
    @Environment(OPClient.self) private var client
    var body: some View {
        // iPad gets a sidebar + detail; iPhone gets the same tabs.
        TabView {
            NavigationStack { MyWorkView() }
                .tabItem { Label("My work", systemImage: "person.crop.rectangle") }
            NavigationStack { ProjectsView() }
                .tabItem { Label("Projects", systemImage: "rectangle.stack") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
