package neko.eam.mobile.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import neko.eam.mobile.R
import neko.eam.mobile.data.ApiException
import neko.eam.mobile.data.AuthInfo
import neko.eam.mobile.data.Session

/**
 * Server URL and - with `authMode=local` - user name / password. On start it tries the stored
 * server and session silently and goes straight to [onReady] when they still work.
 */
@Composable
fun ConnectScreen(session: Session, expired: Boolean, onReady: () -> Unit) {
    val scope = rememberCoroutineScope()
    var url by rememberSaveable { mutableStateOf(session.serverUrl) }
    var user by rememberSaveable { mutableStateOf(session.lastUser) }
    var password by rememberSaveable { mutableStateOf("") }
    var tenant by rememberSaveable { mutableStateOf(session.lastTenant) }
    var info by rememberSaveable(stateSaver = authInfoSaver) { mutableStateOf<AuthInfo?>(null) }
    var busy by rememberSaveable { mutableStateOf(false) }
    var error by rememberSaveable { mutableStateOf<String?>(null) }
    val expiredText = stringResource(R.string.session_expired)

    /** Loads model + user; returns false when a sign-in is needed. */
    suspend fun tryEnter(): Boolean = try {
        session.load()
        onReady()
        true
    } catch (e: ApiException) {
        if (!e.unauthorized) throw e
        false
    }

    suspend fun connect() {
        val i = session.connect(url)
        url = session.serverUrl
        info = i
        if (i.authMode == "xsuaa") return
        if (!i.local || i.signedIn) {
            if (!tryEnter()) error = expiredText
        }
    }

    fun run(block: suspend () -> Unit) {
        if (busy) return
        busy = true
        error = null
        scope.launch {
            try { block() } catch (e: Exception) { error = errorText(e) } finally { busy = false }
        }
    }

    // first start with a stored server: reconnect silently
    LaunchedEffect(Unit) {
        if (info == null && session.hasServer) {
            run {
                connect()
                if (expired && info?.local == true && info?.signedIn == false) error = expiredText
            }
        }
    }

    Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().imePadding().verticalScroll(rememberScrollState()).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(48.dp))
            Avatar("Neko EAM", "neko", size = 72.dp)
            Spacer(Modifier.height(16.dp))
            Text(stringResource(R.string.app_name), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.SemiBold)
            Text(
                "Enterprise Architecture Management",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(32.dp))

            Column(Modifier.widthIn(max = 480.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                val needsLogin = info?.local == true && info?.signedIn == false
                OutlinedTextField(
                    value = url,
                    onValueChange = { url = it; info = null },
                    label = { Text(stringResource(R.string.server_url)) },
                    supportingText = { Text(stringResource(R.string.server_hint)) },
                    singleLine = true,
                    enabled = !busy,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri, imeAction = ImeAction.Go),
                    keyboardActions = KeyboardActions(onGo = { run { connect() } }),
                    modifier = Modifier.fillMaxWidth(),
                )
                if (needsLogin) {
                    OutlinedTextField(
                        value = user, onValueChange = { user = it },
                        label = { Text(stringResource(R.string.user_name)) },
                        singleLine = true, enabled = !busy,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OutlinedTextField(
                        value = password, onValueChange = { password = it },
                        label = { Text(stringResource(R.string.password)) },
                        singleLine = true, enabled = !busy,
                        visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                        keyboardActions = KeyboardActions(onDone = { run { signIn(session, user, password, tenant, ::tryEnter); password = "" } }),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    if (info?.multiTenant == true) {
                        OutlinedTextField(
                            value = tenant, onValueChange = { tenant = it },
                            label = { Text(stringResource(R.string.tenant)) },
                            singleLine = true, enabled = !busy,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
                if (info?.authMode == "xsuaa") {
                    Text(stringResource(R.string.xsuaa_unsupported), color = MaterialTheme.colorScheme.error)
                }
                error?.let { Text(it, color = MaterialTheme.colorScheme.error) }

                Button(
                    onClick = {
                        if (needsLogin) run { signIn(session, user, password, tenant, ::tryEnter); password = "" }
                        else run { connect() }
                    },
                    enabled = !busy && url.isNotBlank() && (!needsLogin || (user.isNotBlank() && password.isNotEmpty())),
                    modifier = Modifier.fillMaxWidth().height(48.dp),
                ) {
                    if (busy) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp, color = MaterialTheme.colorScheme.onPrimary)
                    else Text(stringResource(if (needsLogin) R.string.sign_in else R.string.connect))
                }
                if (needsLogin) {
                    TextButton(onClick = { info = null; error = null }, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                        Text(stringResource(R.string.change_server))
                    }
                }
            }
        }
    }
}

private suspend fun signIn(session: Session, user: String, password: String, tenant: String, enter: suspend () -> Boolean) {
    session.login(user.trim(), password, tenant.trim())
    enter()
}

private val authInfoSaver = androidx.compose.runtime.saveable.Saver<AuthInfo?, List<Any>>(
    save = { it?.let { i -> listOf(i.authMode, i.signedIn, i.multiTenant) } ?: emptyList() },
    restore = { l -> if (l.size == 3) AuthInfo(l[0] as String, l[1] as Boolean, l[2] as Boolean) else null },
)
