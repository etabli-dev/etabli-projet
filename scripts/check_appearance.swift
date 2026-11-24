import Foundation

// Checks ios/App/AppearanceModel.swift: stored-value parsing and fallback, the shared colour table and its contrast,
// the migration of the earlier mode key, the app-language setting and the selection fills (never yellowish).
// swiftc ios/App/AppearanceModel.swift scripts/check_appearance.swift -o /tmp/appearance-check && /tmp/appearance-check
@main
struct CheckAppearance {
    static func main() {
        precondition(AppearancePreference.modeKey == "appearance.mode")
        precondition(AppearancePreference.accentKey == "appearance.accent")

        precondition(AppearanceMode(stored: nil) == .system)
        precondition(AppearanceMode(stored: "dark") == .dark)
        precondition(AppearanceMode(stored: "light") == .light)
        precondition(AppearanceMode(stored: "Dark") == .system)
        precondition(AppearanceMode(stored: "auto") == .system)
        precondition(AppearanceMode.allCases.map(\.rawValue) == ["system", "light", "dark"])

        precondition(AccentChoice(stored: nil) == .coderBlue)
        precondition(AccentChoice(stored: "green") == .green)
        precondition(AccentChoice(stored: "yellow") == .yellow)
        precondition(AccentChoice(stored: "teal") == .coderBlue)  // removed on 2026-11-24
        precondition(AccentChoice(stored: "brown") == .coderBlue)  // removed on 2026-11-24
        precondition(AccentChoice(stored: "établiGreen") == .coderBlue)
        precondition(AccentChoice(stored: "") == .coderBlue)
        precondition(AccentChoice.allCases.map(\.rawValue)
            == ["coderBlue", "green", "yellow", "orange", "red", "purple", "graphite"])

        let table: [AccentChoice: (UInt32, UInt32)] = [
            .coderBlue: (0x1565C0, 0x42A5F5), .green: (0x2E7D32, 0x66BB6A), .yellow: (0x8C6200, 0xFFCA28),
            .orange: (0xBF360C, 0xFFA726), .red: (0xC62828, 0xE57373), .purple: (0x4527A0, 0xB39DDB),
            .graphite: (0x212121, 0xDADADA),
        ]
        for accent in AccentChoice.allCases {
            guard let expected = table[accent] else { preconditionFailure("missing \(accent)") }
            precondition(accent.light == expected.0 && accent.dark == expected.1, "\(accent) value")
            // WCAG: at least 4.5:1 against the mode's background and with the on-accent colour.
            precondition(contrast(accent.light, CoderPalette.backgroundLight) >= 4.5, "\(accent) light/background")
            precondition(contrast(accent.dark, CoderPalette.backgroundDark) >= 4.5, "\(accent) dark/background")
            precondition(contrast(accent.light, CoderPalette.onAccentLight) >= 4.5, "\(accent) light/on-accent")
            precondition(contrast(accent.dark, CoderPalette.onAccentDark) >= 4.5, "\(accent) dark/on-accent")
        }
        precondition(contrast(CoderPalette.foregroundLight, CoderPalette.backgroundLight) >= 4.5)
        precondition(contrast(CoderPalette.foregroundDark, CoderPalette.backgroundDark) >= 4.5)
        precondition(contrast(CoderPalette.foregroundLight, CoderPalette.surfaceLight) >= 4.5)
        precondition(contrast(CoderPalette.foregroundDark, CoderPalette.surfaceDark) >= 4.5)

        // Selection fills (owner rule, 2026-11-24): yellow and orange use the neutral #212121 (light) / #DADADA
        // (dark), every other accent its own colour; no selection tint lands in the yellow hue range (30–70°) in any
        // accent or mode, neither the tint itself nor drawn at `selectionOpacity` over the background and surface.
        precondition(hue(0xDADADA) == nil && hue(0xFF0000) == 0)
        precondition(abs((hue(0xFFA726) ?? 0) - 36) < 1 && abs((hue(0x8C6200) ?? 0) - 42) < 1)
        precondition(isYellowish(blend(0xFFA726, over: CoderPalette.backgroundDark)), "the old orange fill is caught")
        precondition(isYellowish(AccentChoice.yellow.light) && isYellowish(AccentChoice.yellow.dark))
        for accent in AccentChoice.allCases {
            let neutral = accent == .yellow || accent == .orange
            precondition(accent.hasNeutralSelection == neutral, "\(accent) neutral selection")
            precondition(accent.selectionTint(dark: false) == (neutral ? 0x212121 : accent.light), "\(accent) light")
            precondition(accent.selectionTint(dark: true) == (neutral ? 0xDADADA : accent.dark), "\(accent) dark")
            for dark in [false, true] {
                let tint = accent.selectionTint(dark: dark)
                precondition(!isYellowish(tint), "\(accent) selection tint is yellowish (dark: \(dark))")
                let bases = dark ? [CoderPalette.backgroundDark, CoderPalette.surfaceDark]
                    : [CoderPalette.backgroundLight, CoderPalette.surfaceLight]
                for base in bases {
                    precondition(!isYellowish(blend(tint, over: base)),
                                 "\(accent) selection fill over \(String(base, radix: 16)) is yellowish (dark: \(dark))")
                }
            }
        }

        // The earlier Auto/Light/Dark preference moves to the new key once; an existing new value wins.
        let suite = "etabli.appearance.check.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { preconditionFailure("defaults") }
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("dark", forKey: AppearancePreference.legacyModeKey)
        AppearancePreference.migrateLegacyMode(in: defaults)
        precondition(defaults.string(forKey: AppearancePreference.modeKey) == "dark")
        precondition(defaults.object(forKey: AppearancePreference.legacyModeKey) == nil)
        defaults.set("light", forKey: AppearancePreference.legacyModeKey)
        AppearancePreference.migrateLegacyMode(in: defaults)
        precondition(defaults.string(forKey: AppearancePreference.modeKey) == "dark")
        defaults.set("bogus", forKey: AppearancePreference.legacyModeKey)
        defaults.removeObject(forKey: AppearancePreference.modeKey)
        AppearancePreference.migrateLegacyMode(in: defaults)
        precondition(defaults.string(forKey: AppearancePreference.modeKey) == "system")

        // App language: parsing, fallback, preferred-language storage and locale identifiers.
        precondition(AppLanguage.key == "app.language")
        precondition(AppLanguage.allCases.map(\.rawValue) == ["system", "de", "en"])
        precondition(AppLanguage(stored: nil) == .system)
        precondition(AppLanguage(stored: "de") == .de)
        precondition(AppLanguage(stored: "en") == .en)
        precondition(AppLanguage(stored: "fr") == .system)
        precondition(AppLanguage(stored: "DE") == .system)
        precondition(AppLanguage.de.localeIdentifier(region: "AT") == "de_AT")
        precondition(AppLanguage.en.localeIdentifier(region: nil) == "en_GB")
        precondition(AppLanguage.system.localeIdentifier(region: "DE") == nil)
        AppLanguage.de.storePreferredLanguages(in: defaults)
        precondition(defaults.stringArray(forKey: "AppleLanguages") == ["de"])
        AppLanguage.en.storePreferredLanguages(in: defaults)
        precondition(defaults.stringArray(forKey: "AppleLanguages") == ["en"])
        AppLanguage.system.storePreferredLanguages(in: defaults)
        precondition(defaults.persistentDomain(forName: suite)?["AppleLanguages"] == nil)

        print("Appearance: stored-value fallback, colour table, contrast, migration, app language and selection fills passed.")
    }

    static func luminance(_ rgb: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let value = Double((rgb >> shift) & 0xFF) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    /// True for a hue from 30° to 70° (orange-yellow to yellow); greys have no hue.
    static func isYellowish(_ rgb: UInt32) -> Bool {
        guard let hue = hue(rgb) else { return false }
        return (30...70).contains(hue)
    }

    /// The hue in degrees (0..<360), nil for a grey.
    static func hue(_ rgb: UInt32) -> Double? {
        let r = Double((rgb >> 16) & 0xFF) / 255, g = Double((rgb >> 8) & 0xFF) / 255, b = Double(rgb & 0xFF) / 255
        let high = max(r, g, b), delta = high - min(r, g, b)
        guard delta > 0 else { return nil }
        let sector = high == r ? (g - b) / delta : high == g ? (b - r) / delta + 2 : (r - g) / delta + 4
        let degrees = sector * 60
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// `top` drawn at the selection opacity over `base`, as 0xRRGGBB.
    static func blend(_ top: UInt32, over base: UInt32, opacity: Double = AccentChoice.selectionOpacity) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let value = Double((top >> shift) & 0xFF) * opacity + Double((base >> shift) & 0xFF) * (1 - opacity)
            return UInt32(value.rounded()) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }

    static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
