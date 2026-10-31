// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0

package com.raban.etabli.projet.net

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import kotlinx.coroutines.CancellationException
import org.json.JSONException
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

// OpenProject HAL+JSON client — Android twin of OPClient.swift.
// Auth: single long-lived API token sent as `Authorization: Bearer <token>`.

data class OPConfig(val baseURL: String, val hasToken: Boolean, val revision: Int = 0)

sealed class OPError(message: String) : RuntimeException(message) {
    object NotConfigured : OPError("Set the base URL + API token in Settings.")
    class Http(val status: Int, val body: String?) : OPError("Server returned HTTP $status.")
    class Decoding(msg: String) : OPError("Couldn't decode response: $msg.")
    class Transport(msg: String) : OPError("Network error: $msg.")
}

private val Context.opStore by preferencesDataStore(name = "op_config")
private val KEY_URL   = stringPreferencesKey("baseURL")
private val KEY_TOKEN = stringPreferencesKey("token")
private val KEY_ENCRYPTED_TOKEN = stringPreferencesKey("encryptedToken")

class OPClient internal constructor(
    private val store: DataStore<Preferences>,
    private val cipher: CredentialCipher,
    private val http: OkHttpClient = apiTransport(),
) {
    constructor(context: Context) : this(context.opStore, CredentialCipher.android(context.packageName + ".credentials.v1"))

    // Disconnect and later connection attempts invalidate older network replies.
    private val configurationGeneration = AtomicLong()


    val configFlow: Flow<OPConfig?> = store.data.map { prefs ->
        val url = prefs[KEY_URL].orEmpty()
        val tok = (prefs[KEY_ENCRYPTED_TOKEN] ?: prefs[KEY_TOKEN]).orEmpty()
        if (url.isNotEmpty() && tok.isNotEmpty()) OPConfig(url, true, tok.hashCode()) else null
    }

    suspend fun configure(baseURL: String, token: String): OPMe {
        val base = serverBase(baseURL)
        require(token.isNotBlank()) { "Enter an API token" }
        val generation = configurationGeneration.incrementAndGet()
        val me = fetch(Request.Builder().url("$base/api/v3/users/me").header("Authorization", "Bearer $token")
            .header("Accept", "application/hal+json").build()) { OPMe.parse(it) }
        store.edit { p ->
            if (configurationGeneration.get() != generation) throw CancellationException("Account changed")
            p[KEY_URL] = base
            p[KEY_ENCRYPTED_TOKEN] = cipher.encrypt(token, base)
            p.remove(KEY_TOKEN)
        }
        return me
    }

    suspend fun disconnect() {
        configurationGeneration.incrementAndGet()
        store.edit { it.clear() }
    }

    suspend fun testConnection(): OPMe = get("/api/v3/users/me") { OPMe.parse(it) }

    suspend fun listProjects(): List<OPProject> = get("/api/v3/projects?pageSize=200") { root ->
        val arr = root.getJSONObject("_embedded").getJSONArray("elements")
        (0 until arr.length()).map { OPProject.parse(arr.getJSONObject(it)) }
    }

    suspend fun listMyWorkPackages(): List<OPWorkPackage> {
        // OpenProject lets you filter by assignee=me via the standard work_packages endpoint.
        val path = "/api/v3/work_packages?filters=" +
            java.net.URLEncoder.encode(
                "[{\"assignee\":{\"operator\":\"=\",\"values\":[\"me\"]}}]", "UTF-8"
            ) + "&pageSize=100"
        return get(path) { root ->
            val arr = root.getJSONObject("_embedded").getJSONArray("elements")
            (0 until arr.length()).map { OPWorkPackage.parse(arr.getJSONObject(it)) }
        }
    }

    private suspend fun <T> get(path: String, parse: (JSONObject) -> T): T {
        val (url, token) = currentCreds()
        return fetch(Request.Builder().url(serverBase(url) + path).header("Authorization", "Bearer $token")
            .header("Accept", "application/hal+json").build(), parse)
    }
    private suspend fun <T> fetch(request: Request, parse: (JSONObject) -> T): T {
        try { return parse(http.json(request)) }
        catch (e: CancellationException) { throw e }
        catch (e: HttpFailure) { throw OPError.Http(e.status, null) }
        catch (e: ResponseFailure) { throw OPError.Decoding(e.message ?: "Invalid response") }
        catch (e: JSONException) { throw OPError.Decoding(e.message ?: "Missing response fields") }
        catch (e: Exception) { throw OPError.Transport(e.message ?: "Request failed") }
    }

    private suspend fun currentCreds(): Pair<String, String> {
        var tok = ""
        val prefs = store.edit { p ->
            tok = cipher.readAndMigrate(p, KEY_TOKEN, KEY_ENCRYPTED_TOKEN, p[KEY_URL].orEmpty())
        }
        val url = prefs[KEY_URL].orEmpty()
        if (url.isEmpty() || tok.isEmpty()) throw OPError.NotConfigured
        return url to tok
    }
}
