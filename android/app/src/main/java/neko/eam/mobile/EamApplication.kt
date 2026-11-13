package neko.eam.mobile

import android.app.Application
import neko.eam.mobile.data.Session

class EamApplication : Application() {
    lateinit var session: Session
        private set

    override fun onCreate() {
        super.onCreate()
        session = Session(this)
    }
}
