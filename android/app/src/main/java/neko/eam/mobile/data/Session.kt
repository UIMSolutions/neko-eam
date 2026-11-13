package neko.eam.mobile.data

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * App-wide connection state: the configured server, the API client and what the app loaded after
 * connecting (meta model, signed-in user). Lives in [neko.eam.mobile.EamApplication].
 */
class Session(context: Context) {
    private val prefs = context.getSharedPreferences("eam", Context.MODE_PRIVATE)
    private val cookieJar = PersistentCookieJar(context.getSharedPreferences("eam-cookies", Context.MODE_PRIVATE))

    var serverUrl: String
        get() = prefs.getString(KEY_SERVER, "").orEmpty()
        private set(value) = prefs.edit().putString(KEY_SERVER, value).apply()

    var lastUser: String
        get() = prefs.getString(KEY_USER, "").orEmpty()
        set(value) = prefs.edit().putString(KEY_USER, value).apply()

    var lastTenant: String
        get() = prefs.getString(KEY_TENANT, "").orEmpty()
        set(value) = prefs.edit().putString(KEY_TENANT, value).apply()

    private var _api: EamApi? = serverUrl.takeIf { it.isNotEmpty() }?.let { runCatching { EamApi(it, cookieJar) }.getOrNull() }
    val api: EamApi get() = _api ?: error("No server configured")
    val hasServer get() = _api != null

    private val _model = MutableStateFlow<List<EntitySetDef>>(emptyList())
    val model: StateFlow<List<EntitySetDef>> = _model.asStateFlow()

    private val _me = MutableStateFlow<Me?>(null)
    val me: StateFlow<Me?> = _me.asStateFlow()

    fun set(name: String): EntitySetDef? = _model.value.firstOrNull { it.name == name }

    /** Switches to [url] (validated) and returns its sign-in info. */
    suspend fun connect(url: String): AuthInfo {
        val api = EamApi(url, cookieJar)
        val info = api.authInfo()
        if (api.base.toString() != _api?.base?.toString()) cookieJar.clear()
        _api = api
        serverUrl = api.base.toString()
        return info
    }

    suspend fun login(user: String, password: String, tenant: String): LoginResult {
        val r = api.login(user, password, tenant)
        lastUser = user
        lastTenant = tenant
        return r
    }

    /** Loads the meta model and the signed-in user; throws [ApiException] 401 when not signed in. */
    suspend fun load() {
        val me = api.me()
        _model.value = api.model()
        _me.value = me
    }

    suspend fun logout() {
        runCatching { api.logout() }
        cookieJar.clear()
        _me.value = null
    }

    private companion object {
        const val KEY_SERVER = "server"
        const val KEY_USER = "user"
        const val KEY_TENANT = "tenant"
    }
}
