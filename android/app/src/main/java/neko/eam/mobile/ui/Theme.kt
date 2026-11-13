package neko.eam.mobile.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// SAP Fiori 3 ("Quartz") brand colours, so the app looks like a sibling of the Fiori UI
private val FioriBlue = Color(0xFF0A6ED1)
private val FioriBlueDark = Color(0xFF91C8F6)

private val Light = lightColorScheme(
    primary = FioriBlue,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFD6E9FB),
    onPrimaryContainer = Color(0xFF00284D),
    secondary = Color(0xFF354A5F),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFE5EAF0),
    onSecondaryContainer = Color(0xFF1D2D3E),
    background = Color(0xFFF7F7F7),
    surface = Color(0xFFF7F7F7),
    surfaceContainer = Color.White,
    surfaceContainerLow = Color.White,
    surfaceContainerHigh = Color.White,
    surfaceContainerHighest = Color.White,
    surfaceVariant = Color(0xFFEFF1F2),
    error = Color(0xFFBB0000),
)

private val Dark = darkColorScheme(
    primary = FioriBlueDark,
    onPrimary = Color(0xFF00315C),
    primaryContainer = Color(0xFF00497F),
    onPrimaryContainer = Color(0xFFD6E9FB),
    secondary = Color(0xFFB8C6D4),
    secondaryContainer = Color(0xFF2E3E4E),
    background = Color(0xFF12171C),
    surface = Color(0xFF12171C),
    surfaceContainer = Color(0xFF1D232A),
    surfaceContainerHigh = Color(0xFF232A32),
    surfaceContainerHighest = Color(0xFF29313A),
    surfaceVariant = Color(0xFF29313A),
    error = Color(0xFFFF8888),
)

@Composable
fun EamTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = if (isSystemInDarkTheme()) Dark else Light, content = content)
}
