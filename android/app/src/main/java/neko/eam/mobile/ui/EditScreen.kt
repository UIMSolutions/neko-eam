package neko.eam.mobile.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateMap
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import neko.eam.mobile.R
import neko.eam.mobile.data.ApiException
import neko.eam.mobile.data.EntitySetDef
import neko.eam.mobile.data.FieldDef
import neko.eam.mobile.data.Session
import neko.eam.mobile.data.ValueCodec
import neko.eam.mobile.data.formatNumber
import neko.eam.mobile.data.str
import neko.eam.mobile.data.strings
import neko.eam.mobile.data.text
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/** Create ([id] null) or edit form generated from the meta model of [setName]. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditScreen(session: Session, nav: NavHostController, setName: String, id: String?) {
    val model by session.model.collectAsState()
    val set = model.firstOrNull { it.name == setName } ?: return ErrorBox(IllegalStateException("Unknown set $setName"), null)

    val loader = rememberLoad(setName, id) {
        val el = id?.let { session.api.element(setName, it) }
        val values = set.fields.filter { it.editable }.associate { f -> f.name to initialValue(f, el) }
        val refIds = set.fields.filter { it.isReference && it.editable }
            .groupBy { it.reference }
            .mapValues { (_, fs) -> fs.flatMap { f -> idsOf(values[f.name]) }.toSet() }
            .filterValues { it.isNotEmpty() }
        val names = refIds.mapValues { (t, ids) -> runCatching { session.api.names(t, ids) }.getOrDefault(emptyMap()) }
        Triple(el, values, names)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (id == null) stringResource(R.string.new_element, set.label) else stringResource(R.string.edit)) },
                navigationIcon = { BackButton { nav.popBackStack() } },
            )
        },
    ) { padding ->
        LoadContent(loader, Modifier.padding(padding)) { (el, initial, names) ->
            EditForm(session, nav, set, id, el, initial, names, Modifier.padding(padding))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EditForm(
    session: Session,
    nav: NavHostController,
    set: EntitySetDef,
    id: String?,
    element: JsonObject?,
    initial: Map<String, Any?>,
    initialNames: Map<String, Map<String, String>>,
    modifier: Modifier,
) {
    val values = remember { mutableStateMapOf<String, Any?>().apply { putAll(initial) } }
    val names = remember { mutableStateMapOf<String, String>().apply { initialNames.values.forEach { putAll(it) } } }
    val errors = remember { mutableStateMapOf<String, String>() }
    var saving by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }
    val requiredText = stringResource(R.string.unsaved_required)
    val expired = LocalSessionExpired.current
    val fields = set.fields.filter { it.editable }

    fun save() {
        errors.clear()
        val body = LinkedHashMap<String, JsonElement>()
        fields.forEach { f ->
            val encoded = try {
                ValueCodec.encode(f, values[f.name])
            } catch (e: IllegalArgumentException) {
                errors[f.name] = "Invalid number"; return@forEach
            }
            if (f.required && isEmpty(encoded)) errors[f.name] = requiredText
            val changed = if (element == null) !isEmpty(encoded) || f.isBoolean
            else encoded != ValueCodec.encode(f, initial[f.name])
            if (changed) body[f.name] = encoded
        }
        if (errors.isNotEmpty()) return
        if (id != null && body.isEmpty()) { nav.popBackStack(); return }
        saving = true
        scope.launch {
            try {
                val saved = if (id == null) session.api.create(set.name, JsonObject(body))
                else session.api.update(set.name, id, JsonObject(body))
                nav.popBackStack()
                if (id == null) nav.navigate(Routes.detail(set.name, saved.str("id")))
            } catch (e: ApiException) {
                if (e.unauthorized) expired()
                if (e.target.isNotEmpty() && fields.any { it.name == e.target }) errors[e.target] = e.message.orEmpty()
                snackbar.showSnackbar(errorText(e))
            } catch (e: Exception) {
                snackbar.showSnackbar(errorText(e))
            } finally {
                saving = false
            }
        }
    }

    Box(modifier.fillMaxSize()) {
        Column(
            Modifier.fillMaxSize().imePadding().verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            fields.groupBy { it.group.ifEmpty { "General" } }.forEach { (group, fs) ->
                Text(group, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.padding(top = 12.dp, bottom = 4.dp))
                fs.forEach { f -> FieldEditor(session, f, values, names, errors[f.name], enabled = !saving) }
            }
            Row(Modifier.fillMaxWidth().padding(vertical = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp, Alignment.End)) {
                TextButton(onClick = { nav.popBackStack() }, enabled = !saving) { Text(stringResource(R.string.cancel)) }
                androidx.compose.material3.Button(onClick = ::save, enabled = !saving) {
                    if (saving) CircularProgressIndicator(Modifier.padding(end = 8.dp).heightIn(max = 18.dp), strokeWidth = 2.dp)
                    Text(stringResource(R.string.save))
                }
            }
        }
        SnackbarHost(snackbar, Modifier.align(Alignment.BottomCenter))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FieldEditor(
    session: Session,
    f: FieldDef,
    values: SnapshotStateMap<String, Any?>,
    names: SnapshotStateMap<String, String>,
    error: String?,
    enabled: Boolean,
) {
    val label = f.label + if (f.required) " *" else ""
    val supporting: (@Composable () -> Unit)? = error?.let { { Text(it) } }
    when {
        f.isBoolean -> Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
            Switch(checked = values[f.name] == true, onCheckedChange = { values[f.name] = it }, enabled = enabled)
        }

        f.choices.isNotEmpty() && !f.isCollection -> {
            var open by remember { mutableStateOf(false) }
            ExposedDropdownMenuBox(expanded = open, onExpandedChange = { if (enabled) open = it }) {
                OutlinedTextField(
                    value = values[f.name]?.toString().orEmpty(), onValueChange = {}, readOnly = true,
                    label = { Text(label) }, isError = error != null, supportingText = supporting, enabled = enabled,
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = open) },
                    modifier = Modifier.fillMaxWidth().menuAnchor(MenuAnchorType.PrimaryNotEditable),
                )
                ExposedDropdownMenu(expanded = open, onDismissRequest = { open = false }) {
                    val options = if (f.required) f.choices else listOf("") + f.choices
                    options.forEach { c ->
                        DropdownMenuItem(text = { Text(c.ifEmpty { "–" }) }, onClick = { values[f.name] = c; open = false })
                    }
                }
            }
        }

        f.isReference -> {
            var picking by remember { mutableStateOf(false) }
            val ids = idsOf(values[f.name])
            OutlinedTextField(
                value = ids.joinToString(", ") { names[it] ?: it },
                onValueChange = {}, readOnly = true, enabled = enabled,
                label = { Text(label) }, isError = error != null, supportingText = supporting,
                placeholder = { Text(stringResource(R.string.select_value)) },
                trailingIcon = {
                    Row {
                        if (ids.isNotEmpty() && enabled) IconButton(onClick = { values[f.name] = if (f.isCollection) emptyList<String>() else "" }) {
                            Icon(Icons.Filled.Clear, stringResource(R.string.clear))
                        }
                        IconButton(onClick = { picking = true }, enabled = enabled) { Icon(Icons.Filled.Search, stringResource(R.string.select_value)) }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            )
            if (picking) ReferencePicker(session, f, ids, names, onDismiss = { picking = false }) { chosen ->
                values[f.name] = if (f.isCollection) chosen else chosen.firstOrNull().orEmpty()
                picking = false
            }
        }

        f.isDate -> {
            var picking by remember { mutableStateOf(false) }
            val v = values[f.name]?.toString().orEmpty()
            OutlinedTextField(
                value = v, onValueChange = { values[f.name] = it }, enabled = enabled,
                label = { Text(label) }, isError = error != null, supportingText = supporting ?: { Text("YYYY-MM-DD") },
                singleLine = true,
                trailingIcon = { IconButton(onClick = { picking = true }, enabled = enabled) { Icon(Icons.Filled.DateRange, null) } },
                modifier = Modifier.fillMaxWidth(),
            )
            if (picking) {
                val initialMillis = runCatching { LocalDate.parse(v).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli() }.getOrNull()
                val state = rememberDatePickerState(initialSelectedDateMillis = initialMillis)
                DatePickerDialog(
                    onDismissRequest = { picking = false },
                    confirmButton = {
                        TextButton(onClick = {
                            state.selectedDateMillis?.let {
                                values[f.name] = Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate().toString()
                            }
                            picking = false
                        }) { Text(stringResource(R.string.ok)) }
                    },
                    dismissButton = { TextButton(onClick = { picking = false }) { Text(stringResource(R.string.cancel)) } },
                ) { DatePicker(state) }
            }
        }

        else -> OutlinedTextField(
            value = values[f.name]?.toString().orEmpty(),
            onValueChange = { values[f.name] = it },
            enabled = enabled,
            label = { Text(label) },
            isError = error != null,
            supportingText = supporting ?: if (f.isCollection) ({ Text(stringResource(R.string.comma_separated)) }) else null,
            singleLine = !f.multiline,
            minLines = if (f.multiline) 3 else 1,
            keyboardOptions = KeyboardOptions(
                keyboardType = when (f.type) {
                    "Int32" -> KeyboardType.Number
                    "Double" -> KeyboardType.Decimal
                    else -> KeyboardType.Text
                },
            ),
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

/** Searchable list of the elements of the referenced set; single or multiple choice. */
@Composable
private fun ReferencePicker(
    session: Session,
    f: FieldDef,
    selected: List<String>,
    names: SnapshotStateMap<String, String>,
    onDismiss: () -> Unit,
    onDone: (List<String>) -> Unit,
) {
    val target = session.set(f.reference)
    var query by remember { mutableStateOf("") }
    val chosen = remember { mutableStateListOf<String>().apply { addAll(selected) } }
    val results = rememberLoad(f.reference, query) {
        if (query.isNotEmpty()) delay(300)
        session.api.list(f.reference, search = query, select = listOf("id", "name"), top = 100).items
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(target?.label ?: f.label) },
        text = {
            Column {
                OutlinedTextField(
                    value = query, onValueChange = { query = it }, singleLine = true,
                    leadingIcon = { Icon(Icons.Filled.Search, null) },
                    placeholder = { Text(stringResource(R.string.search)) },
                    modifier = Modifier.fillMaxWidth(),
                )
                Box(Modifier.heightIn(min = 120.dp, max = 400.dp)) {
                    LoadContent(results) { items ->
                        if (items.isEmpty()) EmptyBox(stringResource(R.string.no_results))
                        else LazyColumn {
                            items(items, key = { it.str("id") }) { el ->
                                val elId = el.str("id")
                                val name = el.str("name").ifEmpty { elId }
                                val isChosen = elId in chosen
                                fun toggle() {
                                    names[elId] = name
                                    if (f.isCollection) { if (isChosen) chosen.remove(elId) else chosen.add(elId) }
                                    else onDone(listOf(elId))
                                }
                                ListItem(
                                    leadingContent = {
                                        if (f.isCollection) Checkbox(checked = isChosen, onCheckedChange = { toggle() })
                                        else RadioButton(selected = isChosen, onClick = { toggle() })
                                    },
                                    headlineContent = { Text(name, maxLines = 2, overflow = TextOverflow.Ellipsis) },
                                    modifier = Modifier.clickable { toggle() },
                                )
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            if (f.isCollection) TextButton(onClick = { onDone(chosen.toList()) }) {
                Icon(Icons.Filled.Check, null)
                Text(stringResource(R.string.ok), Modifier.padding(start = 4.dp))
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
}

// ---- form value helpers ----

/** Value of the form control: Boolean, List<String> (reference collections) or String. */
private fun initialValue(f: FieldDef, el: JsonObject?): Any? {
    if (el == null) return when {
        f.isBoolean -> f.defaultValue.equals("true", true)
        f.isCollection && f.isReference -> f.defaultValue.split(',').map { it.trim() }.filter { it.isNotEmpty() }
        else -> f.defaultValue
    }
    val v = el[f.name]
    return when {
        f.isBoolean -> (v as? JsonPrimitive)?.booleanOrNull ?: false
        f.isCollection && f.isReference -> v.strings()
        f.isCollection -> v.strings().joinToString(", ")
        f.type == "Double" -> v.text()?.toDoubleOrNull()?.let(::formatNumber).orEmpty()
        else -> v.text().orEmpty()
    }
}

private fun idsOf(v: Any?): List<String> = when (v) {
    is List<*> -> v.mapNotNull { it?.toString() }
    is String -> listOfNotNull(v.takeIf { it.isNotEmpty() })
    else -> emptyList()
}

private fun isEmpty(e: JsonElement) = when (e) {
    JsonNull -> true
    is JsonArray -> e.isEmpty()
    is JsonPrimitive -> e.isString && e.content.isEmpty()
    else -> false
}
