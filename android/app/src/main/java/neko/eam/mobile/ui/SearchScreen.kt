package neko.eam.mobile.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.navigation.NavHostController
import kotlinx.coroutines.delay
import neko.eam.mobile.R
import neko.eam.mobile.data.SearchHit
import neko.eam.mobile.data.Session

/** Central search across all sets (`GET /api/v1/search`). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchScreen(session: Session, nav: NavHostController) {
    var query by rememberSaveable { mutableStateOf("") }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }

    val results = rememberLoad(query) {
        if (query.isBlank()) emptyList<SearchHit>()
        else {
            delay(300)
            session.api.search(query.trim(), top = 100)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = { BackButton { nav.popBackStack() } },
                title = {
                    TextField(
                        value = query,
                        onValueChange = { query = it },
                        placeholder = { Text(stringResource(R.string.search_all)) },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                        colors = TextFieldDefaults.colors(
                            focusedContainerColor = Color.Transparent, unfocusedContainerColor = Color.Transparent,
                            focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent,
                        ),
                        trailingIcon = {
                            if (query.isNotEmpty()) IconButton(onClick = { query = "" }) { Icon(Icons.Filled.Clear, stringResource(R.string.clear)) }
                        },
                        modifier = Modifier.fillMaxWidth().focusRequester(focus),
                    )
                },
            )
        },
    ) { padding ->
        LoadContent(results, Modifier.padding(padding)) { hits ->
            LazyColumn(Modifier.fillMaxSize().padding(padding)) {
                if (hits.isEmpty() && query.isNotBlank()) item { EmptyBox(stringResource(R.string.no_results)) }
                items(hits, key = { it.setName + "/" + it.id }) { hit ->
                    ListItem(
                        leadingContent = { Avatar(hit.typeLabel.ifEmpty { hit.setName }, hit.setName) },
                        headlineContent = { Text(hit.name.ifEmpty { hit.id }, maxLines = 2, overflow = TextOverflow.Ellipsis) },
                        overlineContent = { Text(hit.typeLabel.ifEmpty { hit.setName }) },
                        supportingContent = hit.snippet.ifEmpty { hit.description }.takeIf { it.isNotEmpty() }?.let { s ->
                            { Text(s, maxLines = 2, overflow = TextOverflow.Ellipsis, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                        },
                        modifier = Modifier.clickable { nav.navigate(Routes.detail(hit.setName, hit.id)) },
                    )
                    HorizontalDivider()
                }
            }
        }
    }
}
