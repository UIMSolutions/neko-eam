package neko.eam.mobile.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject
import neko.eam.mobile.R
import neko.eam.mobile.data.ApiException
import neko.eam.mobile.data.EntitySetDef
import neko.eam.mobile.data.Session
import neko.eam.mobile.data.display
import neko.eam.mobile.data.str
import neko.eam.mobile.data.title

private const val PAGE = 50

/** Elements of one set: `$search`, paging with `$skip`, create button when permitted. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ListScreen(session: Session, nav: NavHostController, setName: String) {
    val model by session.model.collectAsState()
    val me by session.me.collectAsState()
    val set = model.firstOrNull { it.name == setName }
    val scope = rememberCoroutineScope()
    val expired = LocalSessionExpired.current

    var query by rememberSaveable { mutableStateOf("") }
    var items by remember { mutableStateOf<List<JsonObject>>(emptyList()) }
    var total by remember { mutableStateOf<Int?>(null) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<Throwable?>(null) }
    var generation by remember { mutableIntStateOf(0) }

    suspend fun page(skip: Int) {
        loading = true
        error = null
        try {
            val p = session.api.list(setName, search = query, top = PAGE, skip = skip)
            items = if (skip == 0) p.items else items + p.items
            total = p.total
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            if (e is ApiException && e.unauthorized) expired()
            error = e
        } finally {
            loading = false
        }
    }

    LaunchedEffect(setName, query, generation) {
        if (query.isNotEmpty()) delay(300) // debounce typing
        page(0)
    }

    val yes = stringResource(R.string.yes)
    val no = stringResource(R.string.no)
    val canCreate = me?.accessFor(setName)?.create == true

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(set?.label ?: setName, maxLines = 1, overflow = TextOverflow.Ellipsis)
                },
                navigationIcon = { BackButton { nav.popBackStack() } },
            )
        },
        floatingActionButton = {
            if (canCreate && set != null) FloatingActionButton(onClick = { nav.navigate(Routes.edit(setName)) }) {
                Icon(Icons.Filled.Add, stringResource(R.string.create))
            }
        },
    ) { padding ->
        PullToRefreshBox(
            isRefreshing = loading && items.isNotEmpty(),
            onRefresh = { generation++ },
            modifier = Modifier.fillMaxSize().padding(padding),
        ) {
            LazyColumn(Modifier.fillMaxSize()) {
                item {
                    OutlinedTextField(
                        value = query,
                        onValueChange = { query = it },
                        placeholder = { Text(stringResource(R.string.search)) },
                        leadingIcon = { Icon(Icons.Filled.Search, null) },
                        trailingIcon = {
                            if (query.isNotEmpty()) IconButton(onClick = { query = "" }) {
                                Icon(Icons.Filled.Clear, stringResource(R.string.clear))
                            }
                        },
                        supportingText = total?.let { { Text(pluralStringResource(R.plurals.elements_count, it, it)) } },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                    )
                }
                items(items, key = { it.str("id") }) { el ->
                    ElementRow(set, el, yes, no) { nav.navigate(Routes.detail(setName, el.str("id"))) }
                    HorizontalDivider()
                }
                item {
                    Box(Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
                        val err = error
                        when {
                            err != null && items.isEmpty() -> ErrorBox(err, { generation++ })
                            err != null -> TextButton(onClick = { scope.launch { page(items.size) } }) {
                                Text(errorText(err) + " · " + stringResource(R.string.retry))
                            }
                            loading -> CircularProgressIndicator()
                            items.isEmpty() -> EmptyBox(stringResource(R.string.no_results))
                            (total ?: 0) > items.size -> TextButton(onClick = { scope.launch { page(items.size) } }) {
                                Text(stringResource(R.string.load_more))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ElementRow(set: EntitySetDef?, el: JsonObject, yes: String, no: String, onClick: () -> Unit) {
    val secondary = set?.listFields.orEmpty()
        .take(3)
        .mapNotNull { f -> el.display(f, yes, no).takeIf { it.isNotEmpty() && !f.isReference } }
        .joinToString(" · ")
    ListItem(
        headlineContent = { Text(el.title(), maxLines = 2, overflow = TextOverflow.Ellipsis) },
        supportingContent = if (secondary.isNotEmpty()) {
            { Text(secondary, maxLines = 1, overflow = TextOverflow.Ellipsis, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        } else null,
        modifier = Modifier.clickable(onClick = onClick),
    )
}
