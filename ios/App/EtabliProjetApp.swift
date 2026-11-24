// Copyright 2026 R. Heller
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

@main
struct EtabliProjetApp: App {

    @State private var client = OPClient()

    init() { AppearancePreference.migrateLegacyMode(in: .standard) }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(client)
                .etabliAppearance()
        }
    }
}
