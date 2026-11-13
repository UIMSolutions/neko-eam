package neko.eam.mobile.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject
import neko.eam.mobile.R
import neko.eam.mobile.data.EntitySetDef
import neko.eam.mobile.data.FieldDef
import neko.eam.mobile.data.Session
import neko.eam.mobile.data.display
import neko.eam.mobile.data.strings
import neko.eam.mobile.data.title

/** An element with the names of everything it references (per target set: id -> name). */
private class Resolved(val element: JsonObject, val names: Map<String, Map<String, String>>)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DetailScreen(session: Session, nav: NavHostController, setName: String, id: String) {
    val model by session.model.collectAsState()
    val me by session.me.collectAsState()
    val set = model.firstOrNull { it.name == setName }
    val access = me?.accessFor(setName)
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }
    var hideEmpty by rememberSaveable { mutableStateOf(true) }
    var confirmDelete by remember { mutableStateOf(false) }
    var menu by remember { mutableStateOf(false) }

    val loader = rememberLoad(setName, id, set) {
        val el = session.api.element(setName, id)
        val refs = set?.fields.orEmpty().filter { it.isReference }
            .groupBy { it.reference }
            .mapValues { (_, fs) -> fs.flatMap { f -> el[f.name].strings() }.toSet() }
            .filterValues { it.isNotEmpty() }
        val names = coroutineScope {
            refs.map { (target, ids) ->
                async { target to runCatching { session.api.names(target, ids) }.getOrDefault(ids.associateWith { it }) }
            }.awaitAll().toMap()
        }
        Resolved(el, names)
    }
    val title = (loader.state as? Load.Ok)?.value?.element?.title() ?: set?.label.orEmpty()

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(set?.label.orEmpty(), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                },
                navigationIcon = { BackButton { nav.popBackStack() } },
                actions = {
                    if (access?.update == true && set != null) IconButton(onClick = { nav.navigate(Routes.edit(setName, id)) }) {
                        Icon(Icons.Filled.Edit, stringResource(R.string.edit))
                    }
                    IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreVert, null) }
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                        DropdownMenuItem(
                            text = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Checkbox(checked = hideEmpty, onCheckedChange = null)
                                    Text(stringResource(R.string.hide_empty), Modifier.padding(start = 8.dp))
                                }
                            },
                            onClick = { hideEmpty = !hideEmpty; menu = false },
                        )
                        DropdownMenuItem(text = { Text(stringResource(R.string.refresh)) }, onClick = { menu = false; loader.reload() })
                        if (access?.remove == true) DropdownMenuItem(
                            text = { Text(stringResource(R.string.delete), color = MaterialTheme.colorScheme.error) },
                            leadingIcon = { Icon(Icons.Filled.Delete, null, tint = MaterialTheme.colorScheme.error) },
                            onClick = { menu = false; confirmDelete = true },
                        )
                    }
                },
            )
        },
    ) { padding ->
        PullToRefreshBox(isRefreshing = loader.refreshing, onRefresh = loader.reload, modifier = Modifier.fillMaxSize().padding(padding)) {
            LoadContent(loader) { r ->
                if (set == null) ErrorBox(IllegalStateException("Unknown set $setName"), null)
                else ElementFields(set, r, hideEmpty) { target, refId -> nav.navigate(Routes.detail(target, refId)) }
            }
        }
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text(stringResource(R.string.delete)) },
            text = { Text(stringResource(R.string.delete_confirm, title)) },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    scope.launch {
                        try {
                            session.api.delete(setName, id)
                            nav.popBackStack()
                        } catch (e: Exception) {
                            // e.g. 409 while other elements still reference it
                            snackbar.showSnackbar(errorText(e))
                        }
                    }
                }) { Text(stringResource(R.string.delete), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text(stringResource(R.string.cancel)) } },
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ElementFields(set: EntitySetDef, r: Resolved, hideEmpty: Boolean, open: (String, String) -> Unit) {
    val yes = stringResource(R.string.yes)
    val no = stringResource(R.string.no)
    val groups = set.fields
        .filter { it.name != "id" }
        .filter { f -> !hideEmpty || hasValue(r.element, f, yes, no) }
        .groupBy { it.group.ifEmpty { "General" } }
        .toList()

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        items(groups, key = { it.first }) { (group, fields) ->
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(group, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold)
                    fields.forEach { f ->
                        Column {
                            Text(f.label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            if (f.isReference) {
                                val ids = r.element[f.name].strings()
                                if (ids.isEmpty()) Text("–")
                                else FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    ids.forEach { refId ->
                                        AssistChip(
                                            onClick = { open(f.reference, refId) },
                                            label = { Text(r.names[f.reference]?.get(refId) ?: refId, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                                        )
                                    }
                                }
                            } else {
                                SelectionContainer {
                                    Text(r.element.display(f, yes, no).ifEmpty { "–" }, style = MaterialTheme.typography.bodyLarge)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private fun hasValue(el: JsonObject, f: FieldDef, yes: String, no: String) = el.display(f, yes, no).isNotEmpty()
