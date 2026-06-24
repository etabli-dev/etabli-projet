// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0

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
//   - Color:      one restrained teal-green accent (#28A745 ≈ Hugo Coder
//                 default), neutral grays otherwise.
//   - Modes:      light + dark via UITraitCollection, plus a persisted
//                 in-app override (Auto / Light / Dark).

public enum Theme {

    public enum Color {
        // Foreground
        public static let ink     = dynamic(hex(0x1A1A1A), hex(0xE6E6E6))
        public static let faint   = dynamic(hex(0x6B6B6B), hex(0x8A9298))

        // Backgrounds
        public static let paper   = dynamic(hex(0xFBFBF9), hex(0x14171A))
        public static let surface = dynamic(hex(0xFFFFFF), hex(0x1B1F23))

        // Single accent (Hugo Coder green)
        public static let accent      = dynamic(hex(0x28A745), hex(0x40C463))
        public static let accentMuted = dynamic(hex(0x28A745, alpha: 0.14),
                                                hex(0x40C463, alpha: 0.20))

        // State
        public static let warn   = dynamic(hex(0x8A6D3B), hex(0xC9A35B))
        public static let danger = dynamic(hex(0x9B3B3B), hex(0xD46A6A))

        // Structure
        public static let hairline = dynamic(hex(0xE2E6E5), hex(0x2A2F34))
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
}

// MARK: - Persisted theme preference (Auto / Light / Dark)

public enum ThemePreference: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    public var id: String { rawValue }
    public static let userDefaultsKey = "coder.theme.preference"
    public var label: String {
        switch self { case .system: "Auto"; case .light: "Light"; case .dark: "Dark" }
    }
    public var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light:  "sun.max"
        case .dark:   "moon"
        }
    }
    public var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

// MARK: - Shared styled components

public struct PromptHeader<Trailing: View>: View {
    public let segments: [String]
    public let trailing: Trailing
    public init(_ segments: [String], @ViewBuilder trailing: () -> Trailing) {
        self.segments = segments; self.trailing = trailing()
    }
    public var body: some View {
        HStack(spacing: 0) {
            Text("~/").font(Theme.Font.monoBody).foregroundStyle(Theme.Color.accent)
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
        .accessibilityLabel("Path: " + (["~"] + segments).joined(separator: "/"))
    }
}
public extension PromptHeader where Trailing == EmptyView {
    init(_ segments: [String]) { self.init(segments, trailing: { EmptyView() }) }
}

public struct MonoLabel: View {
    let text: String; let color: SwiftUI.Color
    public init(_ text: String, color: SwiftUI.Color = Theme.Color.ink) {
        self.text = text; self.color = color
    }
    public var body: some View {
        Text(text).font(Theme.Font.mono).foregroundStyle(color)
    }
}

public struct Card<Content: View>: View {
    let title: String; let systemImage: String?; let content: Content
    public init(title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title; self.systemImage = systemImage; self.content = content()
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            HStack(spacing: Theme.Space.xs) {
                if let systemImage {
                    Image(systemName: systemImage).foregroundStyle(Theme.Color.accent)
                }
                Text(title).font(Theme.Font.headline).foregroundStyle(Theme.Color.ink)
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
    let title: String; let systemImage: String?; let action: () -> Void
    let enabled: Bool
    public init(_ title: String, systemImage: String? = nil, enabled: Bool = true,
                action: @escaping () -> Void) {
        self.title = title; self.systemImage = systemImage
        self.enabled = enabled; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(Theme.Font.body.weight(.semibold))
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.sm)
            .foregroundStyle(Theme.Color.surface)
            .background(enabled ? Theme.Color.accent : Theme.Color.faint)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

public struct StatusLabel: View {
    public enum Tone { case info, accent, warn, danger }
    let text: String; let tone: Tone
    public init(_ text: String, tone: Tone = .info) { self.text = text; self.tone = tone }
    public var body: some View {
        Text(text)
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
        case .accent: Theme.Color.surface
        case .warn:   Theme.Color.surface
        case .danger: Theme.Color.surface
        }
    }
    private var background: SwiftUI.Color {
        switch tone {
        case .info:   Theme.Color.paper
        case .accent: Theme.Color.accent
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
    let title: String
    public init(_ title: String = "loading…") { self.title = title }
    public var body: some View {
        VStack(spacing: Theme.Space.sm) {
            ProgressView().tint(Theme.Color.accent)
            MonoLabel(title, color: Theme.Color.faint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Space.xl)
    }
}

public struct EmptyState: View {
    let title: String; let detail: String?; let systemImage: String
    public init(title: String, detail: String? = nil, systemImage: String = "tray") {
        self.title = title; self.detail = detail; self.systemImage = systemImage
    }
    public var body: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: systemImage).font(.title2).foregroundStyle(Theme.Color.faint)
            Text(title).font(Theme.Font.headline).foregroundStyle(Theme.Color.ink)
            if let detail {
                MonoLabel(detail, color: Theme.Color.faint).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Space.xl)
    }
}

public struct ErrorState: View {
    let title: String; let detail: String?; let retry: (() -> Void)?
    public init(title: String, detail: String? = nil, retry: (() -> Void)? = nil) {
        self.title = title; self.detail = detail; self.retry = retry
    }
    public var body: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2).foregroundStyle(Theme.Color.danger)
            Text(title).font(Theme.Font.headline).foregroundStyle(Theme.Color.ink)
            if let detail {
                MonoLabel(detail, color: Theme.Color.faint).multilineTextAlignment(.center)
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
