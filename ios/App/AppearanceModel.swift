// Copyright 2026 R. Heller
// SPDX-License-Identifier: AGPL-3.0-only

import Foundation

// MARK: - APPEARANCE MODEL
//
// The owner's appearance setting (2026-11-23), the same in every Établi app: light, dark or the device's mode, and an
// accent colour. Same keys, IDs, values and labels on every stack. IDENTICAL across the native apps; Foundation only
// (scripts/check_appearance.swift compiles it with swiftc), Appearance.swift turns the values into colours.
// Stored as raw values in the standard defaults; missing or unknown values fall back to the defaults, never crash.

enum AppearancePreference {
    static let modeKey = "appearance.mode"
    static let accentKey = "appearance.accent"
    /// The earlier Auto/Light/Dark key of these apps; its raw values are the same as `AppearanceMode`'s.
    static let legacyModeKey = "coder.theme.preference"

    /// Moves a mode saved under the earlier key to `modeKey` once; a value already under `modeKey` wins.
    static func migrateLegacyMode(in defaults: UserDefaults) {
        guard let legacy = defaults.string(forKey: legacyModeKey) else { return }
        if defaults.string(forKey: modeKey) == nil {
            defaults.set(AppearanceMode(stored: legacy).rawValue, forKey: modeKey)
        }
        defaults.removeObject(forKey: legacyModeKey)
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// The stored value, or `.system` when it is missing or unknown.
    init(stored: String?) {
        self = stored.flatMap(AppearanceMode.init(rawValue:)) ?? .system
    }
}

/// The app's language (owner, 2026-11-24: "all apps: option to toggle en / de"): the device's language, German or
/// English. Stored under `key`; the choice is also the app's preferred language (`AppleLanguages`), so texts made
/// outside views, system dialogs and permission prompts follow it from the next launch.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case de
    case en

    static let key = "app.language"
    static let preferredLanguagesKey = "AppleLanguages"

    var id: String { rawValue }

    /// The stored value, or `.system` when it is missing or unknown.
    init(stored: String?) {
        self = stored.flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    /// The language code, nil for the device's language.
    var code: String? { self == .system ? nil : rawValue }

    /// Saves the app's preferred language: `[code]`, or none for the device's language.
    func storePreferredLanguages(in defaults: UserDefaults) {
        if let code {
            defaults.set([code], forKey: Self.preferredLanguagesKey)
        } else {
            defaults.removeObject(forKey: Self.preferredLanguagesKey)
        }
    }

    /// The locale identifier for this language with the given region (e.g. `de_CH`); nil for the device's language.
    func localeIdentifier(region: String?) -> String? {
        guard let code else { return nil }
        return "\(code)_\(region ?? (self == .de ? "DE" : "GB"))"
    }
}

/// An accent colour with a value for light and for dark mode, as 0xRRGGBB. The set and order follow the owner's
/// decision of 2026-11-24 (the same in every Établi app); stored values of removed accents fall back to Coder blue.
enum AccentChoice: String, CaseIterable, Identifiable, Sendable {
    case coderBlue
    case green
    case yellow
    case orange
    case red
    case purple
    case graphite

    var id: String { rawValue }

    /// The stored value, or `.coderBlue` when it is missing or unknown.
    init(stored: String?) {
        self = stored.flatMap(AccentChoice.init(rawValue:)) ?? .coderBlue
    }

    /// Light-mode value, each at least 4.5:1 against the light background and with white on it. Coder blue is the
    /// Hugo Coder theme's `$link-color` (luizdepra/hugo-coder, assets/scss/_variables.scss, module
    /// v0.0.0-20260305123245-3d3bbd75d7bb); yellow is the same file's `$fg-color-notice-warning-icon` #FFB300
    /// (hue 42°), darkened to 5.21:1 on #FAFAFA; the others are Material 800 tones of the theme's notice colour
    /// families.
    var light: UInt32 {
        switch self {
        case .coderBlue: 0x1565C0
        case .green: 0x2E7D32
        case .yellow: 0x8C6200
        case .orange: 0xBF360C
        case .red: 0xC62828
        case .purple: 0x4527A0
        case .graphite: 0x212121
        }
    }

    /// Dark-mode value, each at least 4.5:1 against the dark background and with it as the text colour on it. Coder
    /// blue is the theme's `$link-color-dark`; yellow is the colour of the same file's
    /// `$bg-color-notice-warning-content` (#FFCA28, there at 10 % opacity); the others are lighter tones of the same
    /// families.
    var dark: UInt32 {
        switch self {
        case .coderBlue: 0x42A5F5
        case .green: 0x66BB6A
        case .yellow: 0xFFCA28
        case .orange: 0xFFA726
        case .red: 0xE57373
        case .purple: 0xB39DDB
        case .graphite: 0xDADADA
        }
    }
}

extension AccentChoice {
    /// Opacity of selection fills (selected chips and rows) over the surface behind them.
    static let selectionOpacity = 0.16

    /// Owner rule (2026-11-24): no yellow tint in any background, while the accents themselves stay. Yellow and
    /// orange therefore draw selection fills in the mode's neutral foreground grey instead of their own colour.
    var hasNeutralSelection: Bool { self == .yellow || self == .orange }

    /// The colour of a selection fill, drawn at `selectionOpacity`: the accent, or for yellow and orange #212121 in
    /// light and #DADADA in dark mode.
    func selectionTint(dark: Bool) -> UInt32 {
        if hasNeutralSelection { return dark ? CoderPalette.foregroundDark : CoderPalette.foregroundLight }
        return dark ? self.dark : light
    }
}

/// The Hugo Coder theme's neutral colours (luizdepra/hugo-coder, assets/scss/_variables.scss, module
/// v0.0.0-20260305123245-3d3bbd75d7bb), as 0xRRGGBB.
enum CoderPalette {
    static let backgroundLight: UInt32 = 0xFAFAFA  // $bg-color
    static let backgroundDark: UInt32 = 0x212121  // $bg-color-dark
    static let foregroundLight: UInt32 = 0x212121  // $fg-color
    static let foregroundDark: UInt32 = 0xDADADA  // $fg-color-dark
    static let surfaceLight: UInt32 = 0xE0E0E0  // $alt-bg-color
    static let surfaceDark: UInt32 = 0x424242  // $alt-bg-color-dark
    static let borderLight: UInt32 = 0xCCCCCC  // $darker-alt-bg-color
    static let borderDark: UInt32 = 0x4F4F4F  // $lighter-alt-bg-color-dark
    /// Text and symbols on an accent fill: white in light mode, the dark background colour in dark mode.
    static let onAccentLight: UInt32 = 0xFFFFFF
    static let onAccentDark: UInt32 = 0x212121
}
