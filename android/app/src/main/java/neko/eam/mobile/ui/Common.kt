package neko.eam.mobile.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.CancellationException
import neko.eam.mobile.R
import neko.eam.mobile.data.ApiException
import kotlin.math.absoluteValue

/** State of an asynchronous load. */
sealed interface Load<out T> {
    data object Loading : Load<Nothing>
    data class Ok<T>(val value: T) : Load<T>
    data class Failed(val error: Throwable) : Load<Nothing>
}

/** Called when a request finds the session ended - the app returns to sign-in. */
val LocalSessionExpired = staticCompositionLocalOf<() -> Unit> { {} }

class Loader<T>(val state: Load<T>, val reload: () -> Unit, val refreshing: Boolean)

/**
 * Runs [block] whenever [keys] change or [Loader.reload] is called. While reloading, the previous value
 * stays visible ([Loader.refreshing] is true).
 */
@Composable
fun <T> rememberLoad(vararg keys: Any?, block: suspend () -> T): Loader<T> {
    var state by remember(*keys) { mutableStateOf<Load<T>>(Load.Loading) }
    var refreshing by remember(*keys) { mutableStateOf(false) }
    var counter by remember(*keys) { mutableIntStateOf(0) }
    val expired = LocalSessionExpired.current
    LaunchedEffect(*keys, counter) {
        refreshing = state is Load.Ok
        state = try {
            Load.Ok(block())
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            if (e is ApiException && e.unauthorized) expired()
            Load.Failed(e)
        }
        refreshing = false
    }
    return Loader(state, { counter++ }, refreshing)
}

/** Shows loading / error / content of [loader]. */
@Composable
fun <T> LoadContent(loader: Loader<T>, modifier: Modifier = Modifier, content: @Composable (T) -> Unit) {
    when (val s = loader.state) {
        Load.Loading -> Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        is Load.Failed -> ErrorBox(s.error, loader.reload, modifier)
        is Load.Ok -> content(s.value)
    }
}

@Composable
fun ErrorBox(error: Throwable, onRetry: (() -> Unit)?, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(Icons.Filled.Warning, null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(40.dp))
        Text(errorText(error), textAlign = TextAlign.Center, style = MaterialTheme.typography.bodyLarge)
        if (onRetry != null) OutlinedButton(onClick = onRetry) { Text(stringResource(R.string.retry)) }
    }
}

@Composable
fun EmptyBox(text: String, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().padding(48.dp), contentAlignment = Alignment.Center) {
        Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
    }
}

fun errorText(e: Throwable): String = when (e) {
    is ApiException -> e.message ?: e.code
    is java.net.UnknownHostException -> "Server not found: ${e.message}"
    is java.net.ConnectException -> "Cannot connect to the server"
    is java.net.SocketTimeoutException -> "The server does not respond"
    is javax.net.ssl.SSLException -> "TLS error: ${e.message}"
    is kotlinx.serialization.SerializationException -> "Unexpected server response - is this a Neko EAM server?"
    else -> e.message ?: e.javaClass.simpleName
}

@Composable
fun BackButton(onBack: () -> Unit) {
    IconButton(onClick = onBack) {
        Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.back))
    }
}

private val avatarColors = listOf(
    Color(0xFF0A6ED1), Color(0xFF5D36FF), Color(0xFF188918), Color(0xFFDF6E0C),
    Color(0xFFCC00DC), Color(0xFF107E7E), Color(0xFFAA0808), Color(0xFF354A5F),
)

/** Coloured initials of an element type (stable colour per [key]). */
@Composable
fun Avatar(label: String, key: String, size: Dp = 40.dp) {
    val initials = label.split(' ', '-').filter { it.isNotEmpty() }.take(2).joinToString("") { it.take(1).uppercase() }
        .ifEmpty { "?" }
    Box(
        Modifier.size(size).clip(CircleShape).background(avatarColors[key.hashCode().absoluteValue % avatarColors.size]),
        contentAlignment = Alignment.Center,
    ) {
        Text(initials, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = (size.value * 0.38f).sp)
    }
}
