package neko.eam.mobile.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import okhttp3.CookieJar
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

/**
 * Client of the Neko EAM backend: local sign-in (`/auth/...`), the REST API (`/api/v1/...`) and the
 * OData v4 service (`/odata/v4/eam/...`).
 *
 * With `authMode=local` the session lives in the `eam-session` cookie (kept by [cookies]); modifying
 * requests need the session's CSRF token, fetched with `X-CSRF-Token: Fetch` like the SAP approuter
 * protocol the backend implements.
 */
class EamApi(
    baseUrl: String,
    private val cookies: CookieJar,
    client: OkHttpClient? = null,
    private val odataPath: String = "/odata/v4/eam",
) {
    val base: HttpUrl = normalizeBaseUrl(baseUrl)

    private val http = (client?.newBuilder() ?: OkHttpClient.Builder())
        .cookieJar(cookies)
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    @Volatile private var csrfToken: String? = null

    // ---- sign-in ----

    suspend fun authInfo(): AuthInfo = decode(get(url("auth/info")))

    suspend fun login(userName: String, password: String, tenant: String): LoginResult {
        val body = json.encodeToString(LoginRequest.serializer(), LoginRequest(userName, password, tenant))
        csrfToken = null
        return decode(execute(Request.Builder().url(url("auth/login")).post(body.toJsonBody()).build()))
    }

    suspend fun logout() {
        csrfToken = null
        runCatching { execute(Request.Builder().url(url("auth/logout")).post(EMPTY_BODY).build()) }
    }

    // ---- REST ----

    suspend fun me(): Me = decode(get(url("api/v1/me")))

    suspend fun model(): List<EntitySetDef> = decode(get(url("api/v1/model")))

    suspend fun portfolio(): Portfolio = decode(get(url("api/v1/analysis/portfolio")))

    suspend fun search(query: String, top: Int = 50): List<SearchHit> =
        decode(get(url("api/v1/search").newBuilder().addQueryParameter("q", query).addQueryParameter("top", top.toString()).build()))

    suspend fun notifications(): Notifications = decode(get(url("api/v1/notifications")))

    suspend fun markRead(ids: List<String>? = null): Notifications = notificationAction("read", ids)

    suspend fun dismiss(ids: List<String>? = null): Notifications = notificationAction("dismiss", ids)

    private suspend fun notificationAction(action: String, ids: List<String>?): Notifications {
        val body = buildJsonObject {
            if (ids == null) put("all", true) else putJsonArray("ids") { ids.forEach { add(JsonPrimitive(it)) } }
        }
        return decode(modify("POST", url("api/v1/notifications/$action"), body))
    }

    // ---- OData ----

    /** One page of [set]; [search] maps to `$search`, [filter] to `$filter`. */
    suspend fun list(
        set: String,
        search: String = "",
        filter: String = "",
        orderBy: String = "name",
        select: List<String> = emptyList(),
        top: Int = 50,
        skip: Int = 0,
    ): Page {
        val u = odata(set).newBuilder()
            .addQueryParameter("\$top", top.toString())
            .addQueryParameter("\$skip", skip.toString())
            .addQueryParameter("\$count", "true")
        if (search.isNotBlank()) u.addQueryParameter("\$search", search.trim())
        if (filter.isNotBlank()) u.addQueryParameter("\$filter", filter)
        if (orderBy.isNotBlank()) u.addQueryParameter("\$orderby", orderBy)
        if (select.isNotEmpty()) u.addQueryParameter("\$select", select.joinToString(","))
        val o = parseObject(get(u.build()))
        val items = o["value"]?.jsonArray?.map { it.jsonObject }.orEmpty()
        return Page(items, o["@odata.count"]?.jsonPrimitive?.intOrNull)
    }

    suspend fun element(set: String, id: String): JsonObject = parseObject(get(odata(set, id))).withoutAnnotations()

    /** Names of the elements [ids] of [set] (unknown ids map to themselves). */
    suspend fun names(set: String, ids: Collection<String>): Map<String, String> {
        if (ids.isEmpty()) return emptyMap()
        val result = LinkedHashMap<String, String>()
        // keep the URL short: chunks of ids in one `$filter`
        ids.distinct().chunked(25).forEach { chunk ->
            val filter = chunk.joinToString(" or ") { "id eq ${literal(it)}" }
            list(set, filter = filter, orderBy = "", select = listOf("id", "name"), top = chunk.size).items
                .forEach { result[it.str("id")] = it.title() }
        }
        return ids.associateWith { result[it] ?: it }
    }

    suspend fun create(set: String, values: JsonObject): JsonObject =
        parseObject(modify("POST", odata(set), values)).withoutAnnotations()

    suspend fun update(set: String, id: String, changes: JsonObject): JsonObject =
        parseObject(modify("PATCH", odata(set, id), changes)).withoutAnnotations()

    suspend fun delete(set: String, id: String) {
        modify("DELETE", odata(set, id), null)
    }

    // ---- plumbing ----

    private fun url(path: String): HttpUrl = base.resolve(path) ?: error("Invalid path $path")

    private fun odata(set: String, id: String? = null): HttpUrl {
        val b = base.newBuilder()
        odataPath.trim('/').split('/').forEach { b.addPathSegment(it) }
        b.addPathSegment(if (id == null) set else "$set(${literal(id)})")
        return b.build()
    }

    private suspend fun get(u: HttpUrl): String = execute(Request.Builder().url(u).get().build())

    /** Modifying request with the CSRF token; refetches the token once when the server asks for it. */
    private suspend fun modify(method: String, u: HttpUrl, body: JsonObject?): String {
        val payload = body?.toString()?.toJsonBody() ?: if (method == "DELETE") null else EMPTY_BODY
        fun build(token: String?) = Request.Builder().url(u).method(method, payload).apply {
            if (token != null) header(CSRF, token)
        }.build()
        return try {
            execute(build(csrfToken ?: fetchCsrf()))
        } catch (e: ApiException) {
            if (e.status != 403 || e.code != CSRF_REQUIRED) throw e
            csrfToken = null
            execute(build(fetchCsrf()))
        }
    }

    private suspend fun fetchCsrf(): String? = withContext(Dispatchers.IO) {
        val req = Request.Builder().url(url("api/v1/me")).header(CSRF, "Fetch").get().build()
        http.newCall(req).execute().use { r ->
            r.header(CSRF)?.takeIf { it.isNotEmpty() && !it.equals("Required", true) }.also { csrfToken = it }
        }
    }

    private suspend fun execute(req: Request): String = withContext(Dispatchers.IO) {
        http.newCall(req).execute().use { r ->
            val text = r.body?.string().orEmpty()
            if (!r.isSuccessful) {
                if (r.code == 403 && r.header(CSRF).equals("Required", true))
                    throw ApiException(403, CSRF_REQUIRED, "CSRF token validation failed")
                throw parseError(r.code, text)
            }
            // a guarded page answered with the sign-in page instead of JSON
            if (r.request.url.encodedPath.endsWith("login.html"))
                throw ApiException(401, "Unauthorized", "Not signed in")
            text
        }
    }

    private inline fun <reified T> decode(text: String): T = json.decodeFromString(text)

    private fun parseObject(text: String): JsonObject =
        if (text.isBlank()) JsonObject(emptyMap()) else json.parseToJsonElement(text).jsonObject

    companion object {
        const val CSRF = "X-CSRF-Token"
        private const val CSRF_REQUIRED = "CsrfRequired"
        private val JSON_TYPE = "application/json; charset=utf-8".toMediaType()
        private val EMPTY_BODY = ByteArray(0).toRequestBody(null)

        val json = Json { ignoreUnknownKeys = true; coerceInputValues = true; explicitNulls = false }

        private fun String.toJsonBody(): RequestBody = toRequestBody(JSON_TYPE)

        /** `http://host:8080/` from user input such as `host:8080` or `https://host/eam/`. */
        fun normalizeBaseUrl(input: String): HttpUrl {
            var s = input.trim()
            require(s.isNotEmpty()) { "Enter the server URL" }
            if (!s.contains("://")) s = "http://$s"
            if (!s.endsWith("/")) s += "/"
            return s.toHttpUrl()
        }

        /** OData string literal (single quotes doubled). */
        fun literal(value: String) = "'" + value.replace("'", "''") + "'"

        /** OData error `{"error":{"code","message","target"}}` or a plain text body. */
        fun parseError(status: Int, body: String): ApiException {
            val err = runCatching { json.parseToJsonElement(body).jsonObject["error"]?.jsonObject }.getOrNull()
            if (err != null) {
                fun s(k: String) = (err[k] as? JsonPrimitive)?.content.orEmpty()
                return ApiException(status, s("code").ifEmpty { "Error" }, s("message").ifEmpty { "HTTP $status" }, s("target"))
            }
            val msg = when (status) {
                401 -> "Not signed in"
                403 -> "Not authorized"
                404 -> "Not found"
                else -> body.take(200).ifBlank { "HTTP $status" }
            }
            return ApiException(status, "Http$status", msg)
        }

        private fun JsonObject.withoutAnnotations() = JsonObject(filterKeys { !it.startsWith("@") })
    }
}

/** Converts the values typed into the edit form to the JSON types of the meta model. */
object ValueCodec {
    fun encode(field: FieldDef, value: Any?): kotlinx.serialization.json.JsonElement = when {
        field.isCollection -> JsonArray(
            when (value) {
                is Collection<*> -> value.mapNotNull { it?.toString()?.trim()?.takeIf(String::isNotEmpty) }
                is String -> value.split(',').map { it.trim() }.filter { it.isNotEmpty() }
                else -> emptyList()
            }.map(::JsonPrimitive)
        )
        field.isBoolean -> JsonPrimitive(value == true || value.toString().equals("true", true))
        field.type == "Int32" -> value?.toString()?.trim()?.takeIf(String::isNotEmpty)?.let { s ->
            JsonPrimitive(s.toIntOrNull() ?: throw IllegalArgumentException(s))
        } ?: kotlinx.serialization.json.JsonNull
        field.type == "Double" -> value?.toString()?.trim()?.replace(',', '.')?.takeIf(String::isNotEmpty)?.let { s ->
            JsonPrimitive(s.toDoubleOrNull() ?: throw IllegalArgumentException(s))
        } ?: kotlinx.serialization.json.JsonNull
        field.isDate -> value?.toString()?.trim()?.takeIf(String::isNotEmpty)?.let(::JsonPrimitive)
            ?: kotlinx.serialization.json.JsonNull
        else -> JsonPrimitive(value?.toString().orEmpty())
    }
}
