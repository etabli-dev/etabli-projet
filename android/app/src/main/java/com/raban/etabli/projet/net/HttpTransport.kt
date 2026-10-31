// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0
package com.raban.etabli.projet.net

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.*
import okhttp3.HttpUrl.Companion.toHttpUrl
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

internal const val MAX_JSON_BYTES = 8 * 1024 * 1024
internal class HttpFailure(val status: Int) : IOException("Server returned HTTP $status")
internal class ResponseFailure(message: String, cause: Throwable? = null) : IOException(message, cause)

internal fun serverBase(value: String): String {
    val url = value.trim().trimEnd('/').toHttpUrl()
    require(url.isHttps && url.host.isNotBlank() && url.username.isEmpty() && url.password.isEmpty() && url.query == null && url.fragment == null) {
        "Use an HTTPS server URL without embedded credentials, query or fragment"
    }
    return url.toString().trimEnd('/')
}

internal fun apiTransport(): OkHttpClient = OkHttpClient.Builder()
    .connectTimeout(15, TimeUnit.SECONDS).readTimeout(30, TimeUnit.SECONDS)
    .callTimeout(45, TimeUnit.SECONDS).followRedirects(false).followSslRedirects(false).build()

/** Keep cancellation attached until the bounded body has been consumed and closed. */
internal suspend fun OkHttpClient.json(request: Request): JSONObject {
    require(request.url.isHttps && request.url.username.isEmpty() && request.url.password.isEmpty()) { "Authenticated requests require HTTPS" }
    val call = newBuilder().followRedirects(false).followSslRedirects(false).build().newCall(request)
    return suspendCancellableCoroutine { pending ->
        pending.invokeOnCancellation { call.cancel() }
        call.enqueue(object : Callback {
            override fun onFailure(call: Call, error: IOException) { if (!pending.isCancelled) pending.resumeWithException(error) }
            override fun onResponse(call: Call, response: Response) {
                try {
                    val parsed = response.use {
                        if (!it.isSuccessful) throw HttpFailure(it.code)
                        val body = it.body ?: throw ResponseFailure("Empty response")
                        if (body.contentLength() > MAX_JSON_BYTES) throw ResponseFailure("JSON response exceeds 8 MiB")
                        val source = body.source()
                        source.request(MAX_JSON_BYTES.toLong() + 1)
                        if (source.buffer.size > MAX_JSON_BYTES) throw ResponseFailure("JSON response exceeds 8 MiB")
                        try { JSONObject(source.readUtf8()) }
                        catch (e: Exception) { throw ResponseFailure("Invalid JSON response", e) }
                    }
                    if (!pending.isCancelled) pending.resume(parsed)
                } catch (e: Exception) { if (!pending.isCancelled) pending.resumeWithException(e) }
            }
        })
    }
}
