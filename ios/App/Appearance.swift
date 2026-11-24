// Copyright 2026 R. Heller
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit

// MARK: - APPEARANCE (app language, System / Light / Dark and accent colour)
//
// IDENTICAL across the native Établi apps, like Theme.swift. The values live in AppearanceModel.swift. Applied
// app-wide at once by `.etabliAppearance()` at the root of every scene: the language through the environment's
// locale (with the device's region), the mode through the windows' interface style (`preferredColorScheme(nil)` does
// not reliably return to the device's mode after a fixed one), the accent through `.tint`, the windows' tint (alerts)
// and `EnvironmentValues.themeAccent`, selection fills through `EnvironmentValues.themeSelectionTint`. UI tests and
// screenshots can pass `-appearance.mode dark -appearance.accent yellow` and `-AppleLanguages (de)` as launch
// arguments; the language argument wins over the stored choice.

extension EnvironmentValues {
    /// The accent the user chose (Settings → Appearance); `.etabliAppearance()` sets it.
    @Entry var themeAccent: Color = AccentChoice.coderBlue.color
    /// The colour of selection fills, to draw at `AccentChoice.selectionOpacity` (neutral for yellow and orange, see
    /// `AccentChoice.selectionTint(dark:)`); `.etabliAppearance()` sets it.
    @Entry var themeSelectionTint: Color = AccentChoice.coderBlue.selectionColor
}

extension Color {
    /// A colour with one value for light and one for dark mode (0xRRGGBB), resolved by the trait collection.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor(light: light, dark: dark))
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }

    convenience init(light: UInt32, dark: UInt32) {
        self.init { traits in UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light) }
    }
}

extension AccentChoice {
    var color: Color { Color(light: light, dark: dark) }
    var uiColor: UIColor { UIColor(light: light, dark: dark) }
    var selectionColor: Color { Color(light: selectionTint(dark: false), dark: selectionTint(dark: true)) }

    var label: LocalizedStringKey {
        switch self {
        case .coderBlue: "Coder blue"
        case .green: "Green"
        case .yellow: "Yellow"
        case .orange: "Orange"
        case .red: "Red"
        case .purple: "Purple"
        case .graphite: "Graphite"
        }
    }
}

extension AppLanguage {
    /// Language names in their own language, as iOS shows them ("Deutsch" stays "Deutsch" in English).
    var label: Text {
        switch self {
        case .system: Text("System")
        case .de: Text(verbatim: "Deutsch")
        case .en: Text(verbatim: "English")
        }
    }

    /// The locale the views use: this language with the device's region. For `.system` the device's language, also
    /// right after switching back from a fixed one (the running process keeps the language it started with). A
    /// launch argument that sets the language wins.
    var locale: Locale {
        let defaults = UserDefaults.standard
        if defaults.volatileDomain(forName: UserDefaults.argumentDomain)[Self.preferredLanguagesKey] != nil {
            return .autoupdatingCurrent
        }
        let region = Locale.current.region?.identifier
        if let identifier = localeIdentifier(region: region) { return Locale(identifier: identifier) }
        let device = defaults.stringArray(forKey: Self.preferredLanguagesKey) ?? Locale.preferredLanguages
        guard let match = Bundle.preferredLocalizations(from: Bundle.main.localizations, forPreferences: device).first,
              match != "Base" else { return .autoupdatingCurrent }
        return Locale(identifier: region.map { "\(match)_\($0)" } ?? match)
    }
}

extension AppearanceMode {
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// Reads the stored choice and applies it to the scene; use once at the root of every scene.
private struct AppearanceRoot: ViewModifier {
    @AppStorage(AppearancePreference.modeKey) private var mode: AppearanceMode = .system
    @AppStorage(AppearancePreference.accentKey) private var accent: AccentChoice = .coderBlue
    @AppStorage(AppLanguage.key) private var language: AppLanguage = .system

    func body(content: Content) -> some View {
        content
            .environment(\.locale, language.locale)
            .environment(\.themeAccent, accent.color)
            .environment(\.themeSelectionTint, accent.selectionColor)
            .tint(accent.color)
            .onAppear { applyToWindows() }
            .onChange(of: mode) { _, _ in applyToWindows() }
            .onChange(of: accent) { _, _ in applyToWindows() }
    }

    /// Sets the interface style and tint of every window of the app, so sheets and alerts follow too.
    private func applyToWindows() {
        let style = mode.interfaceStyle
        let tint = accent.uiColor
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
                window.tintColor = tint
            }
        }
    }
}

extension View {
    /// The user's appearance (language, mode and accent), applied app-wide.
    func etabliAppearance() -> some View { modifier(AppearanceRoot()) }
}

/// Settings → "Appearance": the app language as a menu, the mode as a segmented picker, the accent as a row of
/// swatches.
struct AppearanceCard: View {
    @AppStorage(AppearancePreference.modeKey) private var mode: AppearanceMode = .system
    @AppStorage(AppearancePreference.accentKey) private var accent: AccentChoice = .coderBlue
    @AppStorage(AppLanguage.key) private var language: AppLanguage = .system

    var body: some View {
        Card(title: "Appearance", systemImage: "paintbrush") {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                HStack {
                    Text("App language").font(Theme.Font.body).foregroundStyle(Theme.Color.ink)
                    Spacer(minLength: Theme.Space.sm)
                    Picker("App language", selection: Binding(
                        get: { language },
                        set: { language = $0; $0.storePreferredLanguages(in: .standard) }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            language.label.tag(language)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .accessibilityIdentifier("settings.appearance.language")
                }
                Picker("Mode", selection: $mode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.appearance.mode")
                Text("Accent colour").font(Theme.Font.mono).foregroundStyle(Theme.Color.faint)
                    .accessibilityHidden(true)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: Theme.Space.sm)],
                          alignment: .leading, spacing: Theme.Space.sm) {
                    ForEach(AccentChoice.allCases) { choice in
                        swatch(choice)
                    }
                }
                Text("Language, mode and accent colour apply at once; system dialogs follow the language from the next launch. Default: Hugo Coder palette.")
                    .font(Theme.Font.caption).foregroundStyle(Theme.Color.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func swatch(_ choice: AccentChoice) -> some View {
        Button {
            accent = choice
        } label: {
            Circle()
                .fill(choice.color)
                .frame(width: 32, height: 32)
                .overlay {
                    if choice == accent {
                        Image(systemName: "checkmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Theme.Color.onAccent)
                    }
                }
                .overlay(Circle().strokeBorder(Theme.Color.hairline))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(choice.label))
        .accessibilityHint(Text("Accent colour"))
        .accessibilityAddTraits(choice == accent ? .isSelected : [])
        .accessibilityIdentifier("settings.appearance.accent.\(choice.rawValue)")
    }
}
