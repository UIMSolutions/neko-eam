package neko.eam.mobile.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import kotlinx.coroutines.launch
import neko.eam.mobile.R
import neko.eam.mobile.data.Notification
import neko.eam.mobile.data.Notifications
import neko.eam.mobile.data.Session

/** Alerts (lifecycle, blacklist, …) and activities of the signed-in user. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(session: Session, nav: NavHostController) {
    val scope = rememberCoroutineScope()
    val loader = rememberLoad("notifications") { session.api.notifications() }
    // the read / dismiss calls answer with the updated list
    var updated by remember { mutableStateOf<Notifications?>(null) }
    val current = updated ?: (loader.state as? Load.Ok)?.value

    fun act(block: suspend () -> Notifications) {
        scope.launch { runCatching { block() }.onSuccess { updated = it } }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.notifications)) },
                navigationIcon = { BackButton { nav.popBackStack() } },
                actions = {
                    if ((current?.unread ?: 0) > 0) TextButton(onClick = { act { session.api.markRead() } }) {
                        Text(stringResource(R.string.mark_all_read))
                    }
                },
            )
        },
    ) { padding ->
        PullToRefreshBox(
            isRefreshing = loader.refreshing,
            onRefresh = { updated = null; loader.reload() },
            modifier = Modifier.fillMaxSize().padding(padding),
        ) {
            LoadContent(loader) { _ ->
                val items = current?.items.orEmpty()
                LazyColumn(Modifier.fillMaxSize()) {
                    if (items.isEmpty()) item { EmptyBox(stringResource(R.string.no_notifications)) }
                    items(items, key = { it.id }) { n ->
                        NotificationRow(
                            n,
                            onOpen = {
                                if (n.unread) act { session.api.markRead(listOf(n.id)) }
                                if (n.elementSet.isNotEmpty() && n.elementId.isNotEmpty()) nav.navigate(Routes.detail(n.elementSet, n.elementId))
                            },
                            onDismiss = { act { session.api.dismiss(listOf(n.id)) } },
                        )
                        HorizontalDivider()
                    }
                }
            }
        }
    }
}

@Composable
private fun NotificationRow(n: Notification, onOpen: () -> Unit, onDismiss: () -> Unit) {
    val alert = n.category == "alert"
    val tint = when (n.priority) {
        "High" -> MaterialTheme.colorScheme.error
        "Medium" -> Color(0xFFDF6E0C)
        else -> MaterialTheme.colorScheme.primary
    }
    ListItem(
        leadingContent = { Icon(if (alert) Icons.Filled.Warning else Icons.Filled.Info, null, tint = tint, modifier = Modifier.size(28.dp)) },
        overlineContent = n.elementName.takeIf { it.isNotEmpty() }?.let { { Text(it) } },
        headlineContent = { Text(n.text, fontWeight = if (n.unread) FontWeight.SemiBold else FontWeight.Normal) },
        supportingContent = listOf(n.actor, n.date.take(16).replace('T', ' ')).filter { it.isNotEmpty() }
            .joinToString(" · ").takeIf { it.isNotEmpty() }?.let { { Text(it) } },
        trailingContent = { IconButton(onClick = onDismiss) { Icon(Icons.Filled.Close, null) } },
        modifier = Modifier.clickable(onClick = onOpen),
    )
}
