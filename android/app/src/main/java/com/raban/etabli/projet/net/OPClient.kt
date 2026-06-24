// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0

package com.raban.etabli.projet.net

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

// OpenProject HAL+JSON client — Android twin of OPClient.swift.
// Auth: single long-lived API token sent as `Authorization: Bearer <token>`.

data class OPConfig(val baseURL: String, val hasToken: Boolean)

sealed class OPError(message: String) : RuntimeException(message) {
    object NotConfigured : OPError("Set the base URL + API token in Settings.")
    class Http(val status: Int, val body: String?) : OPError("Server returned HTTP $status.")
    class Decoding(msg: String) : OPError("Couldn't decode response: $msg.")
    class Transport(msg: String) : OPError("Network error: $msg.")
}

private val Context.opStore by preferencesDataStore(name = "op_config")
private val KEY_URL   = stringPreferencesKey("baseURL")
private val KEY_TOKEN = stringPreferencesKey("token")

class OPClient(private val context: Context) {
    private val http: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    val configFlow: Flow<OPConfig?> = context.opStore.data.map { prefs ->
        val url = prefs[KEY_URL].orEmpty()
        val tok = prefs[KEY_TOKEN].orEmpty()
        if (url.isNotEmpty() && tok.isNotEmpty()) OPConfig(url, true) else null
    }

    suspend fun configure(baseURL: String, token: String) {
        context.opStore.edit { p ->
            p[KEY_URL] = baseURL.trimEnd('/')
            p[KEY_TOKEN] = token
        }
    }

    suspend fun disconnect() {
        context.opStore.edit { it.clear() }
    }

    suspend fun testConnection(): OPMe = get("/api/v3/users/me") { OPMe.parse(it) }

    suspend fun listProjects(): List<OPProject> = get("/api/v3/projects?pageSize=200") { root ->
        val arr = root.optJSONObject("_embedded")?.optJSONArray("elements") ?: return@get emptyList()
        (0 until arr.length()).map { OPProject.parse(arr.getJSONObject(it)) }
    }

    suspend fun listMyWorkPackages(): List<OPWorkPackage> {
        // OpenProject lets you filter by assignee=me via the standard work_packages endpoint.
        val path = "/api/v3/work_packages?filters=" +
            java.net.URLEncoder.encode(
                "[{\"assignee\":{\"operator\":\"=\",\"values\":[\"me\"]}}]", "UTF-8"
            ) + "&pageSize=100"
        return get(path) { root ->
            val arr = root.optJSONObject("_embedded")?.optJSONArray("elements") ?: return@get emptyList()
            (0 until arr.length()).map { OPWorkPackage.parse(arr.getJSONObject(it)) }
        }
    }

    private suspend fun <T> get(path: String, parse: (JSONObject) -> T): T = withContext(Dispatchers.IO) {
        val (url, token) = currentCreds()
        val req = Request.Builder()
            .url(url + path)
            .header("Authorization", "Bearer $token")
            .header("Accept", "application/hal+json")
            .build()
        try {
            http.newCall(req).execute().use { resp ->
                val body = resp.body?.string()
                if (!resp.isSuccessful) throw OPError.Http(resp.code, body)
                try {
                    parse(JSONObject(body.orEmpty()))
                } catch (t: Throwable) {
                    throw OPError.Decoding(t.message ?: "?")
                }
            }
        } catch (e: OPError) { throw e } catch (t: Throwable) {
            throw OPError.Transport(t.message ?: "?")
        }
    }

    private suspend fun currentCreds(): Pair<String, String> {
        val prefs = context.opStore.data.first()
        val url = prefs[KEY_URL].orEmpty()
        val tok = prefs[KEY_TOKEN].orEmpty()
        if (url.isEmpty() || tok.isEmpty()) throw OPError.NotConfigured
        return url to tok
    }
}
