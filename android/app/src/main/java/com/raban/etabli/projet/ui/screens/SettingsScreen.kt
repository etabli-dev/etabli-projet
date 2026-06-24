// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0

package com.raban.etabli.projet.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.raban.etabli.projet.EtabliProjetApplication
import com.raban.etabli.projet.net.OPMe
import com.raban.etabli.projet.ui.theme.*
import kotlinx.coroutines.launch

@Composable
fun SettingsScreen(app: EtabliProjetApplication) {
    val t = Coder.tokens
    val scope = rememberCoroutineScope()
    val current by app.client.configFlow.collectAsState(initial = null)
    var url by remember(current) { mutableStateOf(current?.baseURL ?: "https://") }
    var token by remember { mutableStateOf("") }
    var status by remember { mutableStateOf<String?>(null) }
    var statusTone by remember { mutableStateOf(StatusTone.Info) }
    var me by remember { mutableStateOf<OPMe?>(null) }
    var busy by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier.fillMaxSize().background(t.color.paper)
            .verticalScroll(rememberScrollState()).padding(t.space.lg),
        verticalArrangement = Arrangement.spacedBy(t.space.lg),
    ) {
        PromptHeader(listOf("settings", "openproject"))

        Card(title = "server", icon = Icons.Default.Cloud) {
            MonoLabel("base URL (e.g. https://op.example.com)", color = t.color.faint)
            TextInput(value = url, placeholder = "https://", onChange = { url = it })
        }
        Card(title = "authentication", icon = Icons.Default.Lock) {
            MonoLabel("API token (from My account → Access tokens)", color = t.color.faint)
            TextInput(value = token, placeholder = "paste token…",
                      onChange = { token = it }, isSecret = true)
        }

        Row(horizontalArrangement = Arrangement.spacedBy(t.space.md)) {
            PrimaryButton(if (busy) "Testing…" else "Save & test",
                          icon = Icons.Default.CheckCircle, enabled = !busy) {
                scope.launch {
                    busy = true; status = null; me = null
                    try {
                        app.client.configure(url.trim(), token.trim())
                        me = app.client.testConnection()
                        status = "Connected as ${me!!.name}"
                        statusTone = StatusTone.Accent
                        token = ""
                    } catch (e: Throwable) {
                        status = e.message ?: "Failed"
                        statusTone = StatusTone.Danger
                    } finally { busy = false }
                }
            }
            if (current != null) {
                PrimaryButton("Disconnect", icon = Icons.AutoMirrored.Filled.Logout) {
                    scope.launch {
                        app.client.disconnect()
                        status = "Disconnected"
                        statusTone = StatusTone.Info
                        me = null
                    }
                }
            }
        }
        status?.let { StatusLabel(it, tone = statusTone) }

        Card(title = "current") {
            if (current == null) {
                MonoLabel("not connected.", color = t.color.faint)
            } else {
                Row(horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth()) {
                    MonoLabel("base URL"); MonoLabel(current!!.baseURL, color = t.color.faint)
                }
                Row(horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth()) {
                    MonoLabel("token"); MonoLabel("✓ stored", color = t.color.accent)
                }
                me?.let {
                    Row(horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()) {
                        MonoLabel("user"); MonoLabel(it.name, color = t.color.faint)
                    }
                }
            }
        }
    }
}
