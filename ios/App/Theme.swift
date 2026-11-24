// Copyright 2026 R. Heller
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit

// MARK: - CODER THEME (Hugo "Coder"-inspired)
//
// IDENTICAL across every app in the suite. Copy this file verbatim into
// each new app's App/ folder; do not edit per app. If something genuinely
// needs to change, change it in ALL apps in the same pass.
//
//   - Aesthetic:  minimal, content-first, whitespace-heavy, hairline borders
//                 instead of heavy shadows.
//   - Typography: system monospace for titles, IDs, timestamps, numbers,
//                 status labels; system default for body prose.
//   - Color:      Hugo Coder palette (AppearanceModel.swift) and one accent
//                 the user chooses (default Coder blue); views read it from
//                 `@Environment(\.themeAccent)`, never a fixed colour.
//   - Modes:      light + dark via UITraitCollection, plus a persisted
//                 in-app override (System / Light / Dark, Appearance.swift).

public enum Theme {

    public enum Color {
        // Hugo Coder neutrals (CoderPalette: luizdepra/hugo-coder
        // assets/scss/_variables.scss @ v0.0.0-20260305123245-3d3bbd75d7bb).
        // Foreground
        public static let ink     = dynamic(hex(CoderPalette.foregroundLight), hex(CoderPalette.foregroundDark))
        // Secondary text: Material grey 700 / 400, at least 4.5:1 on paper and surface.
        public static let faint   = dynamic(hex(0x616161), hex(0xBDBDBD))

        // Backgrounds
        public static let paper   = dynamic(hex(CoderPalette.backgroundLight), hex(CoderPalette.backgroundDark))
        public static let surface = dynamic(hex(CoderPalette.surfaceLight), hex(CoderPalette.surfaceDark))

        // Text and symbols on an accent, warn or danger fill.
        public static let onAccent = dynamic(hex(CoderPalette.onAccentLight), hex(CoderPalette.onAccentDark))

        // The accent is the user's choice: views read `@Environment(\.themeAccent)`.
        // Outside a view (no environment) the stored choice, read when called.
        public static var storedAccent: SwiftUI.Color {
            AccentChoice(stored: UserDefaults.standard.string(forKey: AppearancePreference.accentKey)).color
        }

        // State (semantic; does not follow the accent). At least 4.5:1 on
        // paper and surface, and with onAccent on a fill.
        public static let success = dynamic(hex(0x1B5E20), hex(0x81C784))
        public static let warn    = dynamic(hex(0x805300), hex(0xFFCA28))
        public static let danger  = dynamic(hex(0x9B3B3B), hex(0xEF9A9A))

        // Structure
        public static let hairline = dynamic(hex(CoderPalette.borderLight), hex(CoderPalette.borderDark))
    }

    public enum Font {
        public static let display:  SwiftUI.Font = .system(.largeTitle, design: .monospaced, weight: .semibold)
        public static let title:    SwiftUI.Font = .system(.title2,     design: .monospaced, weight: .semibold)
        public static let headline: SwiftUI.Font = .system(.headline,   design: .monospaced)
        public static let body:     SwiftUI.Font = .system(.callout,    design: .default)
        public static let mono:     SwiftUI.Font = .system(.footnote,   design: .monospaced)
        public static let monoBody: SwiftUI.Font = .system(.body,       design: .monospaced)
        public static let number:   SwiftUI.Font = .system(.title2,     design: .monospaced, weight: .semibold)
        public static let caption:  SwiftUI.Font = .system(.caption,    design: .monospaced)
    }

    public enum Space {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    public enum Radius {
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 10
    }

    public enum Layout {
        /// Widest single-column content (iPad, landscape); phones use their full width.
        public static let readable: CGFloat = 720
    }
}

public extension View {
    /// Centres a single-column screen at `Theme.Layout.readable` instead of stretching it across an iPad.
    func readableColumn() -> some View {
        frame(maxWidth: Theme.Layout.readable, alignment: .leading)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Shared styled components
//
// Like `Text`, the components take a string literal as a localized key (looked up in Localizable.xcstrings with the
// environment's locale, so the in-app language applies at once) and a `String` value verbatim (user content,
// server messages, values already localized with `String(localized:)`).

public struct PromptHeader<Trailing: View>: View {
    @Environment(\.themeAccent) private var accent
    public let segments: [String]
    public let trailing: Trailing
    public init(_ segments: [String], @ViewBuilder trailing: () -> Trailing) {
        self.segments = segments; self.trailing = trailing()
    }
    public var body: some View {
        HStack(spacing: 0) {
            Text("~/").font(Theme.Font.monoBody).foregroundStyle(accent)
            ForEach(Array(segments.enumerated()), id: \.offset) { idx, seg in
                if idx > 0 {
                    Text("/").font(Theme.Font.monoBody).foregroundStyle(Theme.Color.faint)
                }
                Text(seg).font(Theme.Font.monoBody).foregroundStyle(Theme.Color.ink)
            }
            Spacer(minLength: Theme.Space.md)
            trailing
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Path: \((["~"] + segments).joined(separator: "/"))"))
    }
}
public extension PromptHeader where Trailing == EmptyView {
    init(_ segments: [String]) { self.init(segments, trailing: { EmptyView() }) }
}

public struct MonoLabel: View {
    let text: Text; let color: SwiftUI.Color
    public init(_ key: LocalizedStringKey, color: SwiftUI.Color = Theme.Color.ink) {
        self.text = Text(key); self.color = color
    }
    @_disfavoredOverload
    public init<S: StringProtocol>(_ text: S, color: SwiftUI.Color = Theme.Color.ink) {
        self.text = Text(text); self.color = color
    }
    public var body: some View {
        text.font(Theme.Font.mono).foregroundStyle(color)
    }
}

public struct Card<Content: View>: View {
    @Environment(\.themeAccent) private var accent
    let title: Text; let systemImage: String?; let content: Content
    public init(title: LocalizedStringKey, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = Text(title); self.systemImage = systemImage; self.content = content()
    }
    @_disfavoredOverload
    public init<S: StringProtocol>(title: S, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = Text(title); self.systemImage = systemImage; self.content = content()
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            HStack(spacing: Theme.Space.xs) {
                if let systemImage {
                    Image(systemName: systemImage).foregroundStyle(accent)
                        .accessibilityHidden(true)
                }
                title.font(Theme.Font.headline).foregroundStyle(Theme.Color.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .padding(Theme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface)
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
            .strokeBorder(Theme.Color.hairline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }
}

public struct PrimaryButton: View {
    @Environment(\.themeAccent) private var accent
    let title: Text; let systemImage: String?; let action: () -> Void
    let enabled: Bool
    public init(_ title: LocalizedStringKey, systemImage: String? = nil, enabled: Bool = true,
                action: @escaping () -> Void) {
        self.title = Text(title); self.systemImage = systemImage
        self.enabled = enabled; self.action = action
    }
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, systemImage: String? = nil, enabled: Bool = true,
                                   action: @escaping () -> Void) {
        self.title = Text(title); self.systemImage = systemImage
        self.enabled = enabled; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.sm) {
                if let systemImage { Image(systemName: systemImage) }
                title.font(Theme.Font.body.weight(.semibold))
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.sm)
            .foregroundStyle(Theme.Color.onAccent)
            .background(enabled ? accent : Theme.Color.faint)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

public struct StatusLabel: View {
    @Environment(\.themeAccent) private var accent
    public enum Tone { case info, accent, success, warn, danger }
    let text: Text; let tone: Tone
    public init(_ key: LocalizedStringKey, tone: Tone = .info) { self.text = Text(key); self.tone = tone }
    @_disfavoredOverload
    public init<S: StringProtocol>(_ text: S, tone: Tone = .info) { self.text = Text(text); self.tone = tone }
    public var body: some View {
        text
            .font(Theme.Font.mono)
            .foregroundStyle(foreground)
            .padding(.horizontal, Theme.Space.xs)
            .padding(.vertical, 2)
            .background(background)
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .strokeBorder(Theme.Color.hairline, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }
    private var foreground: SwiftUI.Color {
        switch tone {
        case .info:   Theme.Color.ink
        case .accent: Theme.Color.onAccent
        case .success: Theme.Color.onAccent
        case .warn:   Theme.Color.onAccent
        case .danger: Theme.Color.onAccent
        }
    }
    private var background: SwiftUI.Color {
        switch tone {
        case .info:   Theme.Color.paper
        case .accent: accent
        case .success: Theme.Color.success
        case .warn:   Theme.Color.warn
        case .danger: Theme.Color.danger
        }
    }
}

public struct ListRow<Leading: View, Trailing: View>: View {
    public let title: String; public let metadata: String?
    public let leading: Leading; public let trailing: Trailing
    public init(title: String, metadata: String? = nil,
                @ViewBuilder leading: () -> Leading,
                @ViewBuilder trailing: () -> Trailing) {
        self.title = title; self.metadata = metadata
        self.leading = leading(); self.trailing = trailing()
    }
    public var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.md) {
            leading.frame(width: 22, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Font.body).foregroundStyle(Theme.Color.ink).lineLimit(1)
                if let metadata {
                    Text(metadata).font(Theme.Font.mono).foregroundStyle(Theme.Color.faint).lineLimit(1)
                }
            }
            Spacer(minLength: Theme.Space.sm)
            trailing
        }
        .padding(.vertical, Theme.Space.sm)
        .contentShape(Rectangle())
    }
}
public extension ListRow where Trailing == EmptyView {
    init(title: String, metadata: String? = nil, @ViewBuilder leading: () -> Leading) {
        self.init(title: title, metadata: metadata, leading: leading, trailing: { EmptyView() })
    }
}

public struct LoadingState: View {
    let title: LocalizedStringKey
    public init(_ title: LocalizedStringKey = "loading…") { self.title = title }
    public var body: some View {
        VStack(spacing: Theme.Space.sm) {
            ProgressView()
            MonoLabel(title, color: Theme.Color.faint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Space.xl)
    }
}

public struct EmptyState: View {
    let title: LocalizedStringKey; let detail: Text?; let systemImage: String
    public init(title: LocalizedStringKey, detail: LocalizedStringKey? = nil, systemImage: String = "tray") {
        self.title = title; self.detail = detail.map { Text($0) }; self.systemImage = systemImage
    }
    @_disfavoredOverload
    public init(title: LocalizedStringKey, detail: String?, systemImage: String = "tray") {
        self.title = title; self.detail = detail.map { Text($0) }; self.systemImage = systemImage
    }
    public var body: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: systemImage).font(.title2).foregroundStyle(Theme.Color.faint)
                .accessibilityHidden(true)
            Text(title).font(Theme.Font.headline).foregroundStyle(Theme.Color.ink)
            if let detail {
                detail.font(Theme.Font.mono).foregroundStyle(Theme.Color.faint).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Space.xl)
    }
}

public struct ErrorState: View {
    let title: LocalizedStringKey; let detail: Text?; let retry: (() -> Void)?
    public init(title: LocalizedStringKey, detail: LocalizedStringKey? = nil, retry: (() -> Void)? = nil) {
        self.title = title; self.detail = detail.map { Text($0) }; self.retry = retry
    }
    @_disfavoredOverload
    public init(title: LocalizedStringKey, detail: String?, retry: (() -> Void)? = nil) {
        self.title = title; self.detail = detail.map { Text($0) }; self.retry = retry
    }
    public var body: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2).foregroundStyle(Theme.Color.danger)
                .accessibilityHidden(true)
            Text(title).font(Theme.Font.headline).foregroundStyle(Theme.Color.ink)
            if let detail {
                detail.font(Theme.Font.mono).foregroundStyle(Theme.Color.faint).multilineTextAlignment(.center)
            }
            if let retry {
                PrimaryButton("Retry", systemImage: "arrow.clockwise", action: retry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Space.xl)
    }
}

// MARK: - Color helpers (file-private)

private func hex(_ rgb: UInt32, alpha: Double = 1) -> SwiftUI.Color {
    let r = Double((rgb >> 16) & 0xFF) / 255.0
    let g = Double((rgb >>  8) & 0xFF) / 255.0
    let b = Double( rgb        & 0xFF) / 255.0
    return SwiftUI.Color(red: r, green: g, blue: b, opacity: alpha)
}
private func dynamic(_ light: SwiftUI.Color, _ dark: SwiftUI.Color) -> SwiftUI.Color {
    SwiftUI.Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
    })
}
