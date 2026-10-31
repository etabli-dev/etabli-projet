package com.raban.etabli.projet.net

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import kotlinx.coroutines.*
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockWebServer
import okhttp3.tls.HandshakeCertificates
import okhttp3.tls.HeldCertificate
import java.nio.file.Files
import javax.crypto.KeyGenerator

internal fun service(block: suspend (MockWebServer, OPClient) -> Unit) = runBlocking {
    val directory = Files.createTempDirectory("client-fixture").toFile()
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    try {
        MockWebServer().use { server ->
            val certificate = HeldCertificate.Builder().addSubjectAlternativeName("localhost").build()
            val serverTls = HandshakeCertificates.Builder().heldCertificate(certificate).build()
            val clientTls = HandshakeCertificates.Builder().addTrustedCertificate(certificate.certificate).build()
            server.useHttps(serverTls.sslSocketFactory(), false)
            server.start()
            val http = apiTransport().newBuilder().sslSocketFactory(clientTls.sslSocketFactory(), clientTls.trustManager).build()
            val store = PreferenceDataStoreFactory.create(scope = scope) { directory.resolve("prefs.preferences_pb") }
            val key = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
            block(server, OPClient(store, CredentialCipher { key }, http))
        }
    } finally {
        scope.cancel()
        scope.coroutineContext[Job]!!.join()
        directory.deleteRecursively()
    }
}
