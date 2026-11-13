package neko.eam.mobile.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import kotlinx.coroutines.launch
import neko.eam.mobile.R
import neko.eam.mobile.data.Session

/** Start page: all element types of the meta model with their element counts. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(session: Session, nav: NavHostController) {
    val model by session.model.collectAsState()
    val me by session.me.collectAsState()
    val scope = rememberCoroutineScope()
    var filter by rememberSaveable { mutableStateOf("") }
    var menu by remember { mutableStateOf(false) }

    val counts = rememberLoad("counts") { session.api.portfolio().counts.associate { it.kind to it.count } }
    val unread = rememberLoad("unread") { session.api.notifications().unread }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(stringResource(R.string.app_name))
                        me?.let {
                            Text(
                                listOfNotNull(it.displayName.ifEmpty { it.name }, it.tenant.name.takeIf { n -> n.isNotEmpty() })
                                    .joinToString(" · "),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                },
                actions = {
                    IconButton(onClick = { nav.navigate(Routes.SEARCH) }) {
                        Icon(Icons.Filled.Search, stringResource(R.string.search))
                    }
                    IconButton(onClick = { nav.navigate(Routes.NOTIFICATIONS) }) {
                        val n = (unread.state as? Load.Ok)?.value ?: 0
                        BadgedBox(badge = { if (n > 0) Badge { Text(if (n > 99) "99+" else n.toString()) } }) {
                            Icon(Icons.Filled.Notifications, stringResource(R.string.notifications))
                        }
                    }
                    IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreVert, null) }
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                        me?.let {
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.signed_in_as, it.displayName.ifEmpty { it.name })) },
                                onClick = {}, enabled = false,
                            )
                            HorizontalDivider()
                        }
                        DropdownMenuItem(text = { Text(stringResource(R.string.refresh)) }, onClick = {
                            menu = false
                            counts.reload(); unread.reload()
                        })
                        DropdownMenuItem(text = { Text(stringResource(R.string.change_server)) }, onClick = {
                            menu = false
                            nav.toConnect(expired = false)
                        })
                        if (me?.authMode == "local") {
                            DropdownMenuItem(text = { Text(stringResource(R.string.sign_out)) }, onClick = {
                                menu = false
                                scope.launch {
                                    session.logout()
                                    nav.toConnect(expired = false)
                                }
                            })
                        }
                    }
                },
            )
        },
    ) { padding ->
        PullToRefreshBox(
            isRefreshing = counts.refreshing,
            onRefresh = { counts.reload(); unread.reload() },
            modifier = Modifier.fillMaxSize().padding(padding),
        ) {
            val shown = model.filter {
                (me?.accessFor(it.name)?.read ?: true) &&
                    (filter.isBlank() || it.label.contains(filter.trim(), ignoreCase = true))
            }
            val countMap = (counts.state as? Load.Ok)?.value.orEmpty()
            LazyColumn(Modifier.fillMaxSize()) {
                item {
                    OutlinedTextField(
                        value = filter,
                        onValueChange = { filter = it },
                        placeholder = { Text(stringResource(R.string.filter_sets)) },
                        singleLine = true,
                        trailingIcon = {
                            if (filter.isNotEmpty()) IconButton(onClick = { filter = "" }) {
                                Icon(Icons.Filled.Clear, stringResource(R.string.clear))
                            }
                        },
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                    )
                }
                items(shown, key = { it.name }) { set ->
                    ListItem(
                        leadingContent = { Avatar(set.label, set.name) },
                        headlineContent = { Text(set.label) },
                        supportingContent = countMap[set.name]?.let { c -> { Text(pluralStringResource(R.plurals.elements_count, c, c)) } },
                        trailingContent = { Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null) },
                        modifier = Modifier.clickable { nav.navigate(Routes.list(set.name)) },
                    )
                }
                if (shown.isEmpty()) item { EmptyBox(stringResource(R.string.no_results)) }
            }
        }
    }
}
