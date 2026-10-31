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
        try { client.configure(server.url("/wrong").toString(), "bad"); fail("Unauthorized accepted") } catch (_: OPError.Http) { }
        assertEquals(before, client.configFlow.first())
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
