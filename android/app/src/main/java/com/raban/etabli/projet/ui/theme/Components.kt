// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0

package com.raban.etabli.projet.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.WarningAmber
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

// Shared styled components — direct counterparts to the iOS Theme.swift's
// PromptHeader, Card, MonoLabel, PrimaryButton, StatusLabel, ListRow,
// LoadingState, EmptyState, ErrorState. Same visual grammar, Kotlin/Compose
// idioms.

@Composable
fun PromptHeader(
    segments: List<String>,
    trailing: (@Composable () -> Unit)? = null,
) {
    val t = Coder.tokens
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text("~/", style = t.font.monoBody.copy(color = t.color.accent))
        segments.forEachIndexed { idx, seg ->
            if (idx > 0) Text("/", style = t.font.monoBody.copy(color = t.color.faint))
            Text(seg, style = t.font.monoBody.copy(color = t.color.ink))
        }
        Spacer(Modifier.weight(1f))
        trailing?.invoke()
    }
}

@Composable
fun MonoLabel(text: String, color: Color? = null) {
    val t = Coder.tokens
    Text(text, style = t.font.mono.copy(color = color ?: t.color.ink))
}

@Composable
fun Card(
    title: String,
    icon: ImageVector? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val t = Coder.tokens
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(t.color.surface, RoundedCornerShape(t.radius.md))
            .border(1.dp, t.color.hairline, RoundedCornerShape(t.radius.md))
            .padding(t.space.lg),
        verticalArrangement = Arrangement.spacedBy(t.space.md),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (icon != null) {
                Icon(icon, contentDescription = null, tint = t.color.accent,
                     modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(t.space.xs))
            }
            Text(title, style = t.font.headline)
        }
        content()
    }
}

@Composable
fun PrimaryButton(
    title: String,
    icon: ImageVector? = null,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val t = Coder.tokens
    val bg = if (enabled) t.color.accent else t.color.faint
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(t.space.sm),
        modifier = Modifier
            .clickable(enabled = enabled, onClick = onClick)
            .background(bg, RoundedCornerShape(t.radius.sm))
            .padding(horizontal = t.space.md, vertical = t.space.sm),
    ) {
        if (icon != null) Icon(icon, contentDescription = null, tint = t.color.surface,
                               modifier = Modifier.size(16.dp))
        Text(title, style = t.font.body.copy(color = t.color.surface))
    }
}

enum class StatusTone { Info, Accent, Warn, Danger }

@Composable
fun StatusLabel(text: String, tone: StatusTone = StatusTone.Info) {
    val t = Coder.tokens
    val (fg, bg) = when (tone) {
        StatusTone.Info   -> t.color.ink to t.color.paper
        StatusTone.Accent -> t.color.surface to t.color.accent
        StatusTone.Warn   -> t.color.surface to t.color.warn
        StatusTone.Danger -> t.color.surface to t.color.danger
    }
    Text(
        text,
        style = t.font.mono.copy(color = fg),
        modifier = Modifier
            .background(bg, RoundedCornerShape(t.radius.sm))
            .border(1.dp, t.color.hairline, RoundedCornerShape(t.radius.sm))
            .padding(horizontal = t.space.xs, vertical = 2.dp)
    )
}

@Composable
fun ListRow(
    title: String,
    metadata: String? = null,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    onClick: (() -> Unit)? = null,
) {
    val t = Coder.tokens
    Row(
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(t.space.md),
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(vertical = t.space.sm),
    ) {
        Box(modifier = Modifier.size(22.dp), contentAlignment = Alignment.Center) {
            leading?.invoke()
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = t.font.body, maxLines = 1)
            if (metadata != null) {
                Text(metadata, style = t.font.mono.copy(color = t.color.faint), maxLines = 1)
            }
        }
        trailing?.invoke()
    }
}

@Composable
fun LoadingState(title: String = "loading…") {
    val t = Coder.tokens
    Column(
        modifier = Modifier.fillMaxSize().padding(t.space.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        CircularProgressIndicator(color = t.color.accent)
        Spacer(Modifier.height(t.space.sm))
        MonoLabel(title, color = t.color.faint)
    }
}

@Composable
fun EmptyState(
    title: String,
    detail: String? = null,
    icon: ImageVector? = null,
) {
    val t = Coder.tokens
    Column(
        modifier = Modifier.fillMaxSize().padding(t.space.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        if (icon != null) {
            Icon(icon, contentDescription = null, tint = t.color.faint,
                 modifier = Modifier.size(28.dp))
            Spacer(Modifier.height(t.space.md))
        }
        Text(title, style = t.font.headline)
        if (detail != null) {
            Spacer(Modifier.height(t.space.xs))
            Text(detail, style = t.font.mono.copy(color = t.color.faint),
                 textAlign = TextAlign.Center)
        }
    }
}

@Composable
fun ErrorState(
    title: String,
    detail: String? = null,
    onRetry: (() -> Unit)? = null,
) {
    val t = Coder.tokens
    Column(
        modifier = Modifier.fillMaxSize().padding(t.space.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(Icons.Default.WarningAmber, contentDescription = null,
             tint = t.color.danger, modifier = Modifier.size(28.dp))
        Spacer(Modifier.height(t.space.md))
        Text(title, style = t.font.headline)
        if (detail != null) {
            Spacer(Modifier.height(t.space.xs))
            Text(detail, style = t.font.mono.copy(color = t.color.faint),
                 textAlign = TextAlign.Center)
        }
        if (onRetry != null) {
            Spacer(Modifier.height(t.space.md))
            PrimaryButton("Retry", onClick = onRetry)
        }
    }
}
