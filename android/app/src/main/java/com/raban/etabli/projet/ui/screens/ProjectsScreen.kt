// Copyright 2026 Raban Heller
// SPDX-License-Identifier: Apache-2.0

package com.raban.etabli.projet.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.raban.etabli.projet.EtabliProjetApplication
import com.raban.etabli.projet.net.OPProject
import com.raban.etabli.projet.ui.theme.*
import kotlinx.coroutines.launch

@Composable
fun ProjectsScreen(app: EtabliProjetApplication) {
    val t = Coder.tokens
    val scope = rememberCoroutineScope()
    val config by app.client.configFlow.collectAsState(initial = null)
    var items by remember { mutableStateOf<List<OPProject>?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }

    fun load() {
        if (config == null) { items = null; error = null; return }
        scope.launch {
            loading = true; error = null
            try { items = app.client.listProjects() }
            catch (e: Throwable) { error = e.message ?: "Failed"; items = null }
            finally { loading = false }
        }
    }

    LaunchedEffect(config) { load() }

    Column(
        modifier = Modifier.fillMaxSize().background(t.color.paper).padding(t.space.lg),
        verticalArrangement = Arrangement.spacedBy(t.space.md),
    ) {
        PromptHeader(listOf("projects", items?.size?.toString() ?: "—"))
        when {
            config == null   -> Card(title = "not connected") {
                MonoLabel("set the server + API token in Settings first.", color = t.color.faint)
            }
            loading           -> LoadingState("loading projects…")
            error != null     -> ErrorState("Couldn't load projects", detail = error, onRetry = ::load)
            items == null     -> Spacer(Modifier.size(0.dp))
            items!!.isEmpty() -> EmptyState("No projects.")
            else              -> LazyColumn(verticalArrangement = Arrangement.spacedBy(t.space.sm)) {
                items(items!!, key = { it.id }) { p ->
                    Card(title = p.name, icon = Icons.Default.Folder) {
                        MonoLabel("id ${p.id} · ${p.identifier ?: "—"}", color = t.color.faint)
                        p.description?.takeIf { it.isNotBlank() }?.let {
                            MonoLabel(it.take(200), color = t.color.ink)
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
