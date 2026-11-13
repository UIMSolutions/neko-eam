package neko.eam.mobile.data

import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.HttpUrl
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

class EamApiTest {
    private lateinit var server: MockWebServer
    private lateinit var api: EamApi

    private class MemoryJar : CookieJar {
        val cookies = mutableListOf<Cookie>()
        override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) { this.cookies.removeAll { c -> cookies.any { it.name == c.name } }; this.cookies += cookies }
        override fun loadForRequest(url: HttpUrl) = cookies.filter { it.matches(url) }
    }

    @Before fun setUp() {
        server = MockWebServer()
        server.start()
        api = EamApi(server.url("/").toString(), MemoryJar())
    }

    @After fun tearDown() = server.shutdown()

    private fun json(body: String, code: Int = 200) =
        MockResponse().setResponseCode(code).setHeader("Content-Type", "application/json").setBody(body)

    @Test fun loginKeepsSessionCookie() = runBlocking {
        server.enqueue(json("""{"userName":"m.weber","displayName":"Markus Weber","tenant":"default"}""")
            .addHeader("Set-Cookie", "eam-session=abc; Path=/; HttpOnly"))
        server.enqueue(json("""{"name":"m.weber","roles":["Architect"]}"""))
        val r = api.login("m.weber", "pw", "")
        assertEquals("Markus Weber", r.displayName)
        val login = server.takeRequest()
        assertEquals("/auth/login", login.path)
        assertTrue(login.body.readUtf8().contains("\"userName\":\"m.weber\""))
        assertEquals("m.weber", api.me().name)
        assertEquals("eam-session=abc", server.takeRequest().getHeader("Cookie"))
    }

    @Test fun modifyingRequestFetchesCsrfTokenAndRetriesOnce() = runBlocking {
        server.enqueue(json("{}").setHeader(EamApi.CSRF, "t1"))           // fetch
        server.enqueue(MockResponse().setResponseCode(403).setHeader(EamApi.CSRF, "Required")) // stale
        server.enqueue(json("{}").setHeader(EamApi.CSRF, "t2"))           // refetch
        server.enqueue(json("""{"@odata.context":"x","id":"n1","name":"New"}""", 201))
        val created = api.create("Applications", JsonObject(mapOf("name" to JsonPrimitive("New"))))
        assertEquals("n1", created.str("id"))
        assertNull(created["@odata.context"])
        assertEquals("Fetch", server.takeRequest().getHeader(EamApi.CSRF))
        assertEquals("t1", server.takeRequest().getHeader(EamApi.CSRF))
        server.takeRequest()
        val post = server.takeRequest()
        assertEquals("POST", post.method)
        assertEquals("/odata/v4/eam/Applications", post.path)
        assertEquals("t2", post.getHeader(EamApi.CSRF))
    }

    @Test fun odataErrorCarriesTarget() = runBlocking {
        server.enqueue(json("{}"))
        server.enqueue(json("""{"error":{"code":"ValidationError","message":"Field 'name' is required","target":"name"}}""", 400))
        try {
            api.update("Applications", "a'b", JsonObject(emptyMap()))
            fail("expected ApiException")
        } catch (e: ApiException) {
            assertEquals(400, e.status)
            assertEquals("name", e.target)
            assertEquals("Field 'name' is required", e.message)
        }
        server.takeRequest()
        assertEquals("/odata/v4/eam/Applications('a''b')", server.takeRequest().requestUrl!!.encodedPath.let { java.net.URLDecoder.decode(it, "UTF-8") })
    }

    @Test fun listSendsQueryOptions() = runBlocking {
        server.enqueue(json("""{"value":[{"id":"a","name":"A"}],"@odata.count":7}"""))
        val p = api.list("Products", search = "java", top = 20, skip = 40)
        assertEquals(7, p.total)
        assertEquals("A", p.items.single().title())
        val u = server.takeRequest().requestUrl!!
        assertEquals("java", u.queryParameter("\$search"))
        assertEquals("20", u.queryParameter("\$top"))
        assertEquals("40", u.queryParameter("\$skip"))
        assertEquals("true", u.queryParameter("\$count"))
    }

    @Test fun namesFallBackToIds() = runBlocking {
        server.enqueue(json("""{"value":[{"id":"x","name":"Ex"}]}"""))
        assertEquals(mapOf("x" to "Ex", "y" to "y"), api.names("Products", listOf("x", "y")))
        assertEquals("id eq 'x' or id eq 'y'", server.takeRequest().requestUrl!!.queryParameter("\$filter"))
    }

    @Test fun unauthorized() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(401).setBody("Unauthorized"))
        try { api.me(); fail() } catch (e: ApiException) { assertTrue(e.unauthorized) }
    }

    @Test fun baseUrlNormalisation() {
        assertEquals("http://host:8080/", EamApi.normalizeBaseUrl(" host:8080 ").toString())
        assertEquals("https://h/eam/", EamApi.normalizeBaseUrl("https://h/eam").toString())
    }

    @Test fun valueCodec() {
        val int = FieldDef("n", type = "Int32")
        val dbl = FieldDef("d", type = "Double")
        val col = FieldDef("c", type = "StringCollection")
        val date = FieldDef("dt", type = "Date")
        assertEquals(JsonPrimitive(5), ValueCodec.encode(int, " 5 "))
        assertEquals(JsonNull, ValueCodec.encode(int, ""))
        assertEquals(JsonPrimitive(1.5), ValueCodec.encode(dbl, "1,5"))
        assertEquals(JsonArray(listOf(JsonPrimitive("a"), JsonPrimitive("b"))), ValueCodec.encode(col, "a, b,,"))
        assertEquals(JsonArray(listOf(JsonPrimitive("x"))), ValueCodec.encode(col, listOf("x")))
        assertEquals(JsonNull, ValueCodec.encode(date, " "))
        try { ValueCodec.encode(int, "abc"); fail() } catch (_: IllegalArgumentException) {}
    }

    @Test fun displayValues() {
        val el = JsonObject(mapOf("cost" to JsonPrimitive(850000), "ok" to JsonPrimitive(true), "ids" to JsonArray(listOf(JsonPrimitive("a"), JsonPrimitive("b")))))
        assertEquals("850000", el.display(FieldDef("cost", type = "Double"), "Y", "N"))
        assertEquals("Y", el.display(FieldDef("ok", type = "Boolean"), "Y", "N"))
        assertEquals("a, b", el.display(FieldDef("ids", type = "StringCollection"), "Y", "N"))
        assertEquals("", el.display(FieldDef("missing"), "Y", "N"))
    }

    @Test fun timestampsInLocalTime() {
        val tz = java.util.TimeZone.getDefault()
        try {
            java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("Europe/Berlin"))
            assertEquals("2026-11-12 11:13", formatTimestamp("2026-11-12T10:13:05.831476Z"))
            assertEquals("2023-04-01", formatTimestamp("2023-04-01"))
            assertEquals("Active", formatTimestamp("Active"))
        } finally {
            java.util.TimeZone.setDefault(tz)
        }
    }
}
