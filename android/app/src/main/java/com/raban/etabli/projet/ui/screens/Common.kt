// Copyright 2026 Raban Heller
// SPDX-License-Identifier: Apache-2.0

package com.raban.etabli.projet.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.raban.etabli.projet.ui.theme.Coder

@Composable
fun TextInput(
    value: String,
    placeholder: String,
    onChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    isSecret: Boolean = false,
    keyboard: KeyboardOptions = KeyboardOptions.Default,
) {
    val t = Coder.tokens
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(t.radius.sm))
            .background(t.color.paper)
            .border(1.dp, t.color.hairline, RoundedCornerShape(t.radius.sm))
            .padding(horizontal = t.space.md, vertical = t.space.sm),
    ) {
        if (value.isEmpty()) {
            Text(placeholder, style = t.font.body.copy(color = t.color.faint))
        }
        BasicTextField(
            value = value,
            onValueChange = onChange,
            textStyle = t.font.body.copy(color = t.color.ink),
            cursorBrush = SolidColor(t.color.accent),
            singleLine = true,
            visualTransformation = if (isSecret) PasswordVisualTransformation() else androidx.compose.ui.text.input.VisualTransformation.None,
            keyboardOptions = keyboard,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}
