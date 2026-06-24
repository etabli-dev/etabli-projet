// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0
//
// CoderTheme.swift - generated from _style/tokens/coder-design-system.json
// DO NOT hand-edit values. Re-derive from the central token file at build time
// (tool/sync_style.sh copies this in). Editing here causes drift across the suite.

import SwiftUI

enum Coder {
    enum Accent {
        static let base = Color(hex: 0x28A745)
        static let dark = Color(hex: 0x1E7E34)
        static let light = Color(hex: 0x48C76A)
    }
    enum Light {
        static let background = Color(hex: 0xFFFFFF)
        static let surface = Color(hex: 0xF7F8FA)
        static let surfaceAlt = Color(hex: 0xEDEFF2)
        static let textPrimary = Color(hex: 0x1A1C1E)
        static let textSecondary = Color(hex: 0x5A5F66)
        static let border = Color(hex: 0xD9DCE1)
        static let error = Color(hex: 0xD32F2F)
    }
    enum Dark {
        static let background = Color(hex: 0x121417)
        static let surface = Color(hex: 0x1A1D21)
        static let surfaceAlt = Color(hex: 0x22262B)
        static let textPrimary = Color(hex: 0xF2F4F6)
        static let textSecondary = Color(hex: 0xA6ACB3)
        static let border = Color(hex: 0x33373D)
        static let error = Color(hex: 0xEF5350)
    }
    enum Spacing {
        static let xs: CGFloat = 4, sm: CGFloat = 8, md: CGFloat = 16
        static let lg: CGFloat = 24, xl: CGFloat = 32, xxl: CGFloat = 48
    }
    enum Radius {
        static let sm: CGFloat = 6, md: CGFloat = 10, lg: CGFloat = 16
    }
    static let fontMono = "JetBrains Mono"
}

extension Color {
    init(hex: UInt) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}
