package com.raban.etabli.projet.net
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.first
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.RecordedRequest
import java.util.concurrent.CountDownLatch
import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.TimeUnit
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import okhttp3.Credentials

class OPClientTest {
    @Test fun validatesAccountThenLoadsHalProjectsAndAssignedWork() = service { server, client ->
        server.enqueue(MockResponse().setBody("""{"id":7,"name":"User"}"""))
        val me = client.configure(server.url("/openproject").toString(), "kept-secret")
        assertEquals(7, me.id)
        assertEquals("Bearer kept-secret", server.takeRequest().getHeader("Authorization"))
        server.enqueue(MockResponse().setBody("""{"_embedded":{"elements":[{"id":3,"name":"Project","identifier":"project"}]}}"""))
        assertEquals("Project", client.listProjects().single().name)
        assertEquals("/openproject/api/v3/projects?pageSize=200", server.takeRequest().path)
        server.enqueue(MockResponse().setBody("""{"_embedded":{"elements":[{"id":9,"subject":"Fix","_links":{"status":{"title":"Open"}}}]}}"""))
        assertEquals("Open", client.listMyWorkPackages().single().statusTitle)
        assertTrue(server.takeRequest().requestUrl!!.queryParameter("filters")!!.contains("\"me\""))
        val before = client.configFlow.first()
        server.enqueue(MockResponse().setResponseCode(401))
        server.enqueue(MockResponse().setResponseCode(401))
        try { client.configure(server.url("/wrong").toString(), "bad"); fail("Unauthorized accepted") } catch (_: OPError.Http) { }
        assertEquals(before, client.configFlow.first())
    }

    @Test fun basicOnlyServerPersistsVerifiedModeAndRestoresIt() = accountService { server, create, store ->
        val basic = Credentials.basic("apikey", "legacy-key", Charsets.UTF_8)
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                if (request.getHeader("Authorization") != basic) return MockResponse().setResponseCode(401)
                return when (request.requestUrl!!.encodedPath) {
                    "/openproject/api/v3/users/me" -> MockResponse().setBody("""{"id":7,"name":"User"}""")
                    "/openproject/api/v3/projects" -> MockResponse().setBody("""{"_embedded":{"elements":[{"id":3,"name":"Project"}]}}""")
                    else -> MockResponse().setResponseCode(404)
                }
            }
        }
        val client = create(45_000)
        assertEquals(7, client.configure(server.url("/openproject").toString(), "legacy-key").id)
        assertEquals("Bearer legacy-key", server.takeRequest().getHeader("Authorization"))
        val fallback = server.takeRequest()
        assertEquals(basic, fallback.getHeader("Authorization"))
        assertEquals("GET", fallback.method)
        assertEquals("/openproject/api/v3/users/me", fallback.path)
        assertEquals("basic", store.data.first()[stringPreferencesKey("authMode")])
        assertFalse(store.data.first().asMap().values.contains("legacy-key"))
        val restored = create(45_000)
        assertEquals("Project", restored.listProjects().single().name)
        assertEquals(basic, server.takeRequest().getHeader("Authorization"))
        assertEquals(7, restored.testConnection().id)
        assertEquals(basic, server.takeRequest().getHeader("Authorization"))
        assertEquals(4, server.requestCount)
        val before = store.data.first()
        try {
            restored.configure(server.url("/openproject").toString(), "bad")
            fail("Invalid candidate accepted")
        } catch (error: OPError.Http) { assertEquals(401, error.status) }
        assertEquals(before, store.data.first())
        assertEquals(7, create(45_000).testConnection().id)
        assertEquals(7, server.requestCount)
    }

    @Test fun storedCredentialsWithoutModeRemainBearer() = accountService { server, create, store ->
        store.edit { prefs ->
            prefs[stringPreferencesKey("baseURL")] = server.url("/openproject").toString().trimEnd('/')
            prefs[stringPreferencesKey("token")] = "old-token"
        }
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse =
                if (request.getHeader("Authorization") in listOf("Bearer old-token", "Bearer opapi-current"))
                    MockResponse().setBody("""{"id":7,"name":"User"}""")
                else MockResponse().setResponseCode(401)
        }
        assertEquals(7, create(45_000).testConnection().id)
        assertEquals(1, server.requestCount)
        assertNull(store.data.first()[stringPreferencesKey("token")])
        assertNotNull(store.data.first()[stringPreferencesKey("encryptedToken")])
        assertEquals(7, create(45_000).configure(server.url("/openproject").toString(), "opapi-current").id)
        assertEquals("bearer", store.data.first()[stringPreferencesKey("authMode")])
        assertEquals(2, server.requestCount)
        assertEquals(7, create(45_000).testConnection().id)
        assertEquals(3, server.requestCount)
    }

    @Test fun onlyOne401FallbackAndNoFallbackForOtherFailures() = service { server, client ->
        server.enqueue(MockResponse().setBody("""{"id":7,"name":"Existing"}"""))
        client.configure(server.url("/").toString(), "kept-secret")
        val before = client.configFlow.first()
        val cases = listOf(401 to 2, 403 to 1, 307 to 1, 500 to 1, 200 to 1)
        for ((status, count) in cases) {
            val start = server.requestCount
            repeat(count) { server.enqueue(MockResponse().setResponseCode(status).setBody("{}").setHeader("Location", "https://other.invalid")) }
            try {
                client.configure(server.url("/candidate").toString(), "bad")
                fail("Invalid candidate accepted")
            } catch (error: OPError) {
                if (status == 200) assertTrue(error is OPError.Decoding)
                else assertEquals(status, (error as OPError.Http).status)
            }
            assertEquals(count, server.requestCount - start)
            assertEquals(before, client.configFlow.first())
        }
    }

    @Test fun disconnectDuringBasicFallbackCannotRestoreCredentials() = accountService { server, create, store ->
        val release = CountDownLatch(1)
        val arrived = CountDownLatch(1)
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                if (request.getHeader("Authorization")!!.startsWith("Bearer ")) return MockResponse().setResponseCode(401)
                arrived.countDown()
                check(release.await(5, TimeUnit.SECONDS))
                return MockResponse().setBody("""{"id":7,"name":"User"}""")
            }
        }
        val client = create(45_000)
        coroutineScope {
            val pending = async { client.configure(server.url("/").toString(), "legacy") }
            try {
                assertTrue(withContext(Dispatchers.IO) { arrived.await(3, TimeUnit.SECONDS) })
                client.disconnect()
            } finally { release.countDown() }
            assertTrue(runCatching { pending.await() }.exceptionOrNull() is CancellationException)
        }
        assertTrue(store.data.first().asMap().isEmpty())
        assertEquals(2, server.requestCount)
    }

    @Test fun bothAuthenticationAttemptsShareOneDeadline() = accountService { server, create, store ->
        // Each attempt fits a fresh deadline, but together they exceed the shared one.
        server.enqueue(MockResponse().setResponseCode(401).setHeadersDelay(1000, TimeUnit.MILLISECONDS))
        server.enqueue(MockResponse().setBody("""{"id":7,"name":"Too late"}""").setHeadersDelay(1500, TimeUnit.MILLISECONDS))
        try {
            create(2000).configure(server.url("/").toString(), "legacy")
            fail("The fallback received a fresh deadline")
        } catch (_: TimeoutCancellationException) { }
        assertEquals(2, server.requestCount)
        assertTrue(store.data.first().asMap().isEmpty())
    }
    @Test fun malformedHalAndRedirectsFailExplicitly() = service { server, client ->
        server.enqueue(MockResponse().setBody("""{"id":7,"name":"User"}"""))
        client.configure(server.url("/").toString(), "secret")
        server.enqueue(MockResponse().setBody("{}"))
        try { client.listProjects(); fail("Missing embedded list accepted") } catch (_: OPError.Decoding) { }
        server.enqueue(MockResponse().setResponseCode(307).setHeader("Location", "https://other.invalid"))
        try { client.listMyWorkPackages(); fail("Redirect followed") } catch (e: OPError.Http) { assertEquals(307, e.status) }
        assertEquals(3, server.requestCount)
        try { client.configure("http://example.org", "secret"); fail("Insecure server accepted") } catch (_: IllegalArgumentException) { }
    }

    @Test fun disconnectWinsOverAnOlderConnectionResponse() = service { server, client ->
        server.enqueue(MockResponse().setBody("""{"id":1,"name":"Existing user"}"""))
        client.configure(server.url("/").toString(), "existing-secret")
        assertNotNull(client.configFlow.first())
        server.takeRequest()
        val release = CountDownLatch(1)
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                check(release.await(5, TimeUnit.SECONDS)) { "Test did not release the response" }
                return MockResponse().setBody("""{"id":7,"name":"User"}""")
            }
        }
        coroutineScope {
            val pending = async { client.configure(server.url("/").toString(), "secret") }
            try {
                withContext(Dispatchers.IO) { assertNotNull(server.takeRequest(3, TimeUnit.SECONDS)) }
                client.disconnect()
            } finally {
                release.countDown()
            }
            val error = runCatching { pending.await() }.exceptionOrNull()
            assertTrue("The older connection should be cancelled", error is CancellationException)
            assertEquals("Account changed", error?.message)
            assertNull(client.configFlow.first())
        }
    }
}
