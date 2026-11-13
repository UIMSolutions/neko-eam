package neko.eam.mobile

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import neko.eam.mobile.ui.EamNavHost
import neko.eam.mobile.ui.EamTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val session = (application as EamApplication).session
        setContent {
            EamTheme {
                EamNavHost(session)
            }
        }
    }
}
