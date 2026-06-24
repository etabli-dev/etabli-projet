// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0
//
// CoderTheme.kt - generated from _style/tokens/coder-design-system.json
// DO NOT hand-edit values. Re-derive from the central token file at build time
// (tool/sync_style.sh copies this in). Editing here causes drift across the suite.

package com.raban.etabli.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

object Coder {
    val AccentBase = Color(0xFF28A745)
    val AccentDark = Color(0xFF1E7E34)
    val AccentLight = Color(0xFF48C76A)

    object Light {
        val background = Color(0xFFFFFFFF)
        val surface = Color(0xFFF7F8FA)
        val surfaceAlt = Color(0xFFEDEFF2)
        val textPrimary = Color(0xFF1A1C1E)
        val textSecondary = Color(0xFF5A5F66)
        val border = Color(0xFFD9DCE1)
        val error = Color(0xFFD32F2F)
    }
    object Dark {
        val background = Color(0xFF121417)
        val surface = Color(0xFF1A1D21)
        val surfaceAlt = Color(0xFF22262B)
        val textPrimary = Color(0xFFF2F4F6)
        val textSecondary = Color(0xFFA6ACB3)
        val border = Color(0xFF33373D)
        val error = Color(0xFFEF5350)
    }

    val SpacingXs = 4.dp; val SpacingSm = 8.dp; val SpacingMd = 16.dp
    val SpacingLg = 24.dp; val SpacingXl = 32.dp; val SpacingXxl = 48.dp
    val RadiusSm = 6.dp; val RadiusMd = 10.dp; val RadiusLg = 16.dp
}

private val LightColors = lightColorScheme(
    primary = Coder.AccentBase, background = Coder.Light.background,
    surface = Coder.Light.surface, error = Coder.Light.error,
    onBackground = Coder.Light.textPrimary, onSurface = Coder.Light.textPrimary
)
private val DarkColors = darkColorScheme(
    primary = Coder.AccentBase, background = Coder.Dark.background,
    surface = Coder.Dark.surface, error = Coder.Dark.error,
    onBackground = Coder.Dark.textPrimary, onSurface = Coder.Dark.textPrimary
)

@Composable
fun CoderTheme(
    dark: Boolean = isSystemInDarkTheme(),   // system mode by default
    content: @Composable () -> Unit
) {
    MaterialTheme(colorScheme = if (dark) DarkColors else LightColors, content = content)
}
