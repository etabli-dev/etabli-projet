// Copyright 2026 R. Heller
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

@main
struct EtabliProjetApp: App {

    @AppStorage(ThemePreference.userDefaultsKey) private var themeRaw: String = ThemePreference.system.rawValue
    @State private var client = OPClient()

    private var theme: ThemePreference { ThemePreference(rawValue: themeRaw) ?? .system }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(client)
                .preferredColorScheme(theme.colorScheme)
                .tint(Theme.Color.accent)
        }
    }
}
