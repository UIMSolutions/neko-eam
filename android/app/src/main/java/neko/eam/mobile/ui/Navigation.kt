package neko.eam.mobile.ui

import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import neko.eam.mobile.data.Session

object Routes {
    const val CONNECT = "connect?expired={expired}"
    const val HOME = "home"
    const val SEARCH = "search"
    const val NOTIFICATIONS = "notifications"
    const val LIST = "list/{set}"
    const val DETAIL = "detail/{set}/{id}"
    const val EDIT = "edit/{set}?id={id}"

    fun connect(expired: Boolean = false) = "connect?expired=$expired"
    fun list(set: String) = "list/${Uri.encode(set)}"
    fun detail(set: String, id: String) = "detail/${Uri.encode(set)}/${Uri.encode(id)}"
    fun edit(set: String, id: String? = null) = "edit/${Uri.encode(set)}" + (id?.let { "?id=${Uri.encode(it)}" } ?: "")
}

/** Leaves everything and shows the connect / sign-in screen. */
fun NavHostController.toConnect(expired: Boolean) = navigate(Routes.connect(expired)) {
    popUpTo(0) { inclusive = true }
    launchSingleTop = true
}

@Composable
fun EamNavHost(session: Session) {
    val nav = rememberNavController()
    val expired = remember(nav) {
        {
            if (nav.currentDestination?.route != Routes.CONNECT) nav.toConnect(expired = true)
        }
    }
    CompositionLocalProvider(LocalSessionExpired provides expired) {
        NavHost(nav, startDestination = Routes.connect()) {
            composable(
                Routes.CONNECT,
                arguments = listOf(navArgument("expired") { type = NavType.BoolType; defaultValue = false }),
            ) { entry ->
                ConnectScreen(session, entry.arguments?.getBoolean("expired") == true) {
                    nav.navigate(Routes.HOME) { popUpTo(0) { inclusive = true } }
                }
            }
            composable(Routes.HOME) { HomeScreen(session, nav) }
            composable(Routes.SEARCH) { SearchScreen(session, nav) }
            composable(Routes.NOTIFICATIONS) { NotificationsScreen(session, nav) }
            composable(Routes.LIST) { e -> ListScreen(session, nav, e.arguments?.getString("set").orEmpty()) }
            composable(Routes.DETAIL) { e ->
                DetailScreen(session, nav, e.arguments?.getString("set").orEmpty(), e.arguments?.getString("id").orEmpty())
            }
            composable(
                Routes.EDIT,
                arguments = listOf(navArgument("id") { type = NavType.StringType; nullable = true; defaultValue = null }),
            ) { e ->
                EditScreen(session, nav, e.arguments?.getString("set").orEmpty(), e.arguments?.getString("id"))
            }
        }
    }
}
