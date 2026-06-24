// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0

package com.raban.etabli.projet.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// MARK: - CODER THEME (Hugo "Coder"-inspired) — Android twin
//
// Token-for-token copy of the iOS Theme.swift. Monospace for titles/IDs/
// timestamps/numbers, system default for body; single restrained accent
// (#28A745). Hairline borders, generous whitespace. Light+Dark from system
// PLUS a persisted in-app override via ThemePreference.

object CoderColors {
    // Light
    val InkLight     = Color(0xFF1A1A1A)
    val FaintLight   = Color(0xFF6B6B6B)
    val PaperLight   = Color(0xFFFBFBF9)
    val SurfaceLight = Color(0xFFFFFFFF)
    val HairlineLight= Color(0xFFE2E6E5)
    val AccentLight  = Color(0xFF28A745)
    val WarnLight    = Color(0xFF8A6D3B)
    val DangerLight  = Color(0xFF9B3B3B)

    // Dark
    val InkDark      = Color(0xFFE6E6E6)
    val FaintDark    = Color(0xFF8A9298)
    val PaperDark    = Color(0xFF14171A)
    val SurfaceDark  = Color(0xFF1B1F23)
    val HairlineDark = Color(0xFF2A2F34)
    val AccentDark   = Color(0xFF40C463)
    val WarnDark     = Color(0xFFC9A35B)
    val DangerDark   = Color(0xFFD46A6A)
}

// Semantic palette resolved against the current scheme — usage sites read
// `Coder.color.ink` / `Coder.color.accent` instead of raw hex.
data class CoderPalette(
    val ink: Color,
    val faint: Color,
    val paper: Color,
    val surface: Color,
    val hairline: Color,
    val accent: Color,
    val accentMuted: Color,
    val warn: Color,
    val danger: Color,
)

// Whitespace + corner radius tokens — same scale as the iOS Theme.
data class CoderSpace(
    val xs: Dp = 4.dp,
    val sm: Dp = 8.dp,
    val md: Dp = 12.dp,
    val lg: Dp = 16.dp,
    val xl: Dp = 24.dp,
    val xxl: Dp = 32.dp,
)
data class CoderRadius(val sm: Dp = 6.dp, val md: Dp = 10.dp)

// Font tokens. We use FontFamily.Monospace for titles/numbers/labels,
// FontFamily.Default for body prose — the same split the iOS theme uses.
data class CoderFonts(
    val display: TextStyle,
    val title: TextStyle,
    val headline: TextStyle,
    val body: TextStyle,
    val mono: TextStyle,
    val monoBody: TextStyle,
    val number: TextStyle,
    val caption: TextStyle,
)

data class CoderTokens(
    val color: CoderPalette,
    val font: CoderFonts,
    val space: CoderSpace = CoderSpace(),
    val radius: CoderRadius = CoderRadius(),
)

val LocalCoder = staticCompositionLocalOf<CoderTokens> {
    error("CoderTokens not provided")
}

object Coder {
    val tokens: CoderTokens
        @Composable get() = LocalCoder.current
}

private fun lightPalette() = CoderPalette(
    ink         = CoderColors.InkLight,
    faint       = CoderColors.FaintLight,
    paper       = CoderColors.PaperLight,
    surface     = CoderColors.SurfaceLight,
    hairline    = CoderColors.HairlineLight,
    accent      = CoderColors.AccentLight,
    accentMuted = CoderColors.AccentLight.copy(alpha = 0.14f),
    warn        = CoderColors.WarnLight,
    danger      = CoderColors.DangerLight,
)
private fun darkPalette() = CoderPalette(
    ink         = CoderColors.InkDark,
    faint       = CoderColors.FaintDark,
    paper       = CoderColors.PaperDark,
    surface     = CoderColors.SurfaceDark,
    hairline    = CoderColors.HairlineDark,
    accent      = CoderColors.AccentDark,
    accentMuted = CoderColors.AccentDark.copy(alpha = 0.20f),
    warn        = CoderColors.WarnDark,
    danger      = CoderColors.DangerDark,
)

private fun buildFonts(palette: CoderPalette) = CoderFonts(
    display  = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 34.sp, fontWeight = FontWeight.SemiBold, color = palette.ink),
    title    = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 22.sp, fontWeight = FontWeight.SemiBold, color = palette.ink),
    headline = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = palette.ink),
    body     = TextStyle(fontFamily = FontFamily.Default,   fontSize = 16.sp, color = palette.ink),
    mono     = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 13.sp, color = palette.ink),
    monoBody = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 17.sp, color = palette.ink),
    number   = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 22.sp, fontWeight = FontWeight.SemiBold, color = palette.accent),
    caption  = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 12.sp, color = palette.faint),
)

// Material3 color scheme mapping — only used to satisfy MaterialTheme for
// built-in widgets (Pickers, Sliders, system dialogs). We override almost
// everything in-Compose with Coder tokens.
private fun materialLight(p: CoderPalette) = lightColorScheme(
    primary = p.accent,
    onPrimary = p.surface,
    background = p.paper,
    onBackground = p.ink,
    surface = p.surface,
    onSurface = p.ink,
    outline = p.hairline,
    error = p.danger,
)
private fun materialDark(p: CoderPalette) = darkColorScheme(
    primary = p.accent,
    onPrimary = p.surface,
    background = p.paper,
    onBackground = p.ink,
    surface = p.surface,
    onSurface = p.ink,
    outline = p.hairline,
    error = p.danger,
)

@Composable
fun CoderTheme(
    darkOverride: Boolean? = null,   // null = follow system
    content: @Composable () -> Unit
) {
    val dark = darkOverride ?: isSystemInDarkTheme()
    val palette = if (dark) darkPalette() else lightPalette()
    val fonts = buildFonts(palette)
    val tokens = CoderTokens(color = palette, font = fonts)

    val typography = Typography(
        displayLarge = fonts.display,
        titleLarge = fonts.title,
        titleMedium = fonts.headline,
        bodyMedium = fonts.body,
        labelSmall = fonts.caption,
    )
    val material = if (dark) materialDark(palette) else materialLight(palette)

    MaterialTheme(colorScheme = material, typography = typography) {
        CompositionLocalProvider(LocalCoder provides tokens, content = content)
    }
}
