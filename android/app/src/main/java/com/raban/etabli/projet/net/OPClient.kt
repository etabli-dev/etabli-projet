// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0

package com.raban.etabli.projet.net

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withTimeout
import org.json.JSONException
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Credentials
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

// OpenProject HAL+JSON client — Android twin of OPClient.swift.
// Negotiate personal API-token authentication only during the safe connection GET.

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
private val KEY_AUTH_MODE = stringPreferencesKey("authMode")

private enum class AuthMode(val stored: String) {
    Bearer("bearer"), Basic("basic");

    fun authorization(token: String): String = when (this) {
        Bearer -> "Bearer $token"
        Basic -> Credentials.basic("apikey", token, Charsets.UTF_8)
    }

    companion object {
        fun restore(value: String?): AuthMode = when (value) {
            null, "bearer" -> Bearer
            "basic" -> Basic
            else -> throw OPError.Decoding("Stored authentication mode is invalid; reconnect.")
        }
    }
}

private data class StoredCredentials(val server: String, val token: String, val mode: AuthMode)

class OPClient internal constructor(
    private val store: DataStore<Preferences>,
    private val cipher: CredentialCipher,
    private val http: OkHttpClient = apiTransport(),
    private val connectionTimeoutMillis: Long = 45_000,
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
        val (me, mode) = withTimeout(connectionTimeoutMillis) {
            suspend fun verify(mode: AuthMode): OPMe {
                currentCoroutineContext().ensureActive()
                if (configurationGeneration.get() != generation) throw CancellationException("Account changed")
                return fetch(Request.Builder().url("$base/api/v3/users/me")
                    .header("Authorization", mode.authorization(token))
                    .header("Accept", "application/hal+json").build()) { OPMe.parse(it) }
            }
            try {
                verify(AuthMode.Bearer) to AuthMode.Bearer
            } catch (error: OPError.Http) {
                if (error.status != 401) throw error
                verify(AuthMode.Basic) to AuthMode.Basic
            }
        }
        store.edit { p ->
            currentCoroutineContext().ensureActive()
            if (configurationGeneration.get() != generation) throw CancellationException("Account changed")
            p[KEY_URL] = base
            p[KEY_ENCRYPTED_TOKEN] = cipher.encrypt(token, base)
            p[KEY_AUTH_MODE] = mode.stored
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
        val credentials = currentCreds()
        return fetch(Request.Builder().url(serverBase(credentials.server) + path)
            .header("Authorization", credentials.mode.authorization(credentials.token))
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

    private suspend fun currentCreds(): StoredCredentials {
        var tok = ""
        var mode = AuthMode.Bearer
        val prefs = store.edit { p ->
            mode = AuthMode.restore(p[KEY_AUTH_MODE])
            tok = cipher.readAndMigrate(p, KEY_TOKEN, KEY_ENCRYPTED_TOKEN, p[KEY_URL].orEmpty())
        }
        val url = prefs[KEY_URL].orEmpty()
        if (url.isEmpty() || tok.isEmpty()) throw OPError.NotConfigured
        return StoredCredentials(url, tok, mode)
    }
}
