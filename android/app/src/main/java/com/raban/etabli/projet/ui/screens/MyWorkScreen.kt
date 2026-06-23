// Copyright 2026 Raban Heller
// SPDX-License-Identifier: Apache-2.0

package com.raban.etabli.projet.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Assignment
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.raban.etabli.projet.EtabliProjetApplication
import com.raban.etabli.projet.net.OPWorkPackage
import com.raban.etabli.projet.ui.theme.*
import kotlinx.coroutines.launch

@Composable
fun MyWorkScreen(app: EtabliProjetApplication) {
    val t = Coder.tokens
    val scope = rememberCoroutineScope()
    val config by app.client.configFlow.collectAsState(initial = null)
    var items by remember { mutableStateOf<List<OPWorkPackage>?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }

    fun load() {
        if (config == null) { items = null; error = null; return }
        scope.launch {
            loading = true; error = null
            try { items = app.client.listMyWorkPackages() }
            catch (e: Throwable) { error = e.message; items = null }
            finally { loading = false }
        }
    }
    LaunchedEffect(config) { load() }

    Column(
        modifier = Modifier.fillMaxSize().background(t.color.paper).padding(t.space.lg),
        verticalArrangement = Arrangement.spacedBy(t.space.md),
    ) {
        PromptHeader(listOf("my work", items?.size?.toString() ?: "—"))
        when {
            config == null   -> Card(title = "not connected") {
                MonoLabel("set the server + API token in Settings first.", color = t.color.faint)
            }
            loading           -> LoadingState("loading work packages…")
            error != null     -> ErrorState("Couldn't load", detail = error, onRetry = ::load)
            items == null     -> Spacer(Modifier.size(0.dp))
            items!!.isEmpty() -> EmptyState("Nothing assigned to you.")
            else              -> LazyColumn(verticalArrangement = Arrangement.spacedBy(t.space.sm)) {
                items(items!!, key = { it.id }) { wp ->
                    Card(title = "#${wp.id}  ${wp.subject}", icon = Icons.AutoMirrored.Filled.Assignment) {
                        wp.projectTitle?.let { MonoLabel("project · $it", color = t.color.faint) }
                        Row(horizontalArrangement = Arrangement.spacedBy(t.space.sm)) {
                            wp.statusTitle?.let { StatusLabel(it, tone = StatusTone.Accent) }
                            wp.typeTitle?.let { StatusLabel(it, tone = StatusTone.Info) }
                            wp.priorityTitle?.let { StatusLabel(it, tone = StatusTone.Warn) }
                        }
                    }
                }
                item { Spacer(Modifier.height(t.space.xl)) }
            }
        }
        if (config != null) {
            PrimaryButton("Reload", icon = Icons.Default.Refresh, onClick = ::load)
        }
    }
}
