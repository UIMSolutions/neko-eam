package neko.eam.mobile.data

import android.content.SharedPreferences
import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

/**
 * Cookie jar that keeps cookies across app restarts, including session cookies (the server's sign-in
 * session ends after its own idle timeout, so restoring the cookie only helps while it is still valid).
 */
class PersistentCookieJar(private val prefs: SharedPreferences) : CookieJar {
    private val cookies = mutableMapOf<String, Cookie>()

    init {
        prefs.getStringSet(KEY, emptySet()).orEmpty().forEach { line ->
            val sep = line.indexOf('\n')
            if (sep < 0) return@forEach
            val url = line.substring(0, sep).toHttpUrlOrNull() ?: return@forEach
            Cookie.parse(url, line.substring(sep + 1))?.let { cookies[key(it)] = it }
        }
    }

    @Synchronized
    override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
        val now = System.currentTimeMillis()
        cookies.forEach { c ->
            // the server ends a cookie with an empty value / Max-Age=0
            if (c.expiresAt < now || c.value.isEmpty()) this.cookies.remove(key(c)) else this.cookies[key(c)] = c
        }
        persist()
    }

    @Synchronized
    override fun loadForRequest(url: HttpUrl): List<Cookie> {
        val now = System.currentTimeMillis()
        val expired = cookies.filterValues { it.expiresAt < now }.keys
        if (expired.isNotEmpty()) {
            expired.forEach(cookies::remove)
            persist()
        }
        return cookies.values.filter { it.matches(url) }
    }

    @Synchronized
    fun clear() {
        cookies.clear()
        persist()
    }

    private fun persist() {
        prefs.edit().putStringSet(KEY, cookies.values.mapTo(HashSet()) { c ->
            val scheme = if (c.secure) "https" else "http"
            "$scheme://${c.domain}${c.path}\n$c"
        }).apply()
    }

    private fun key(c: Cookie) = "${c.domain}|${c.path}|${c.name}"

    private companion object {
        const val KEY = "cookies"
    }
}
