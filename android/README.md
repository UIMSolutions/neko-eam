# Neko EAM – Android app

Native Android client (Kotlin, Jetpack Compose, Material 3 in Fiori colours) for the Neko EAM server.
It is a sixth channel next to OData, Fiori, WebView, GtkD and CLI, and like the Fiori UI it is **generic**:
every screen is generated at runtime from the meta model (`GET /api/v1/model`). New entity sets and
fields appear in the app without an app update.

| Screen | Backend |
|---|---|
| Connect / sign-in: server URL, user, password, tenant (multi-tenant servers only) | `GET /auth/info`, `POST /auth/login`, `POST /auth/logout` |
| Home: all sets the user may read, with element counts, filter | `/api/v1/model`, `/api/v1/me`, `/api/v1/analysis/portfolio` |
| List: `$search`, paging (50 per page), pull to refresh, create button | `GET /odata/v4/eam/<Set>?$search&$top&$skip&$count` |
| Detail: fields grouped like the object page; references show names and open the target | `GET <Set>('<id>')`, `$filter=id eq … or …` for the names |
| Create / edit: form from the meta model (text, multiline, numbers, yes/no, value lists, date picker, single / multi reference picker); server validation errors appear on the field (`error.target`) | `POST <Set>`, `PATCH <Set>('<id>')` (changed fields only) |
| Delete (with confirmation; a 409 for referenced elements is shown) | `DELETE <Set>('<id>')` |
| Central search | `GET /api/v1/search?q=&top=` |
| Notifications: alerts and activities, mark read, dismiss | `/api/v1/notifications[/read|/dismiss]` |

Create, edit and delete buttons follow the user's permissions (`access.sets` of `/api/v1/me`).

## Authentication

* `authMode=none` (development): no sign-in, the app connects directly.
* `authMode=local`: user name and password, as in `login.html`. The `eam-session` cookie is kept across
  app restarts (it is excluded from backups), and modifying requests send the CSRF token (`X-CSRF-Token: Fetch`,
  refetched once on `Required`). When the session ends, the app returns to the sign-in screen.
* `authMode=xsuaa`: not supported yet. The app says so.

Cleartext `http://` is allowed for intranet and developer servers, and user-installed CA certificates are
trusted (company CAs). Use `https://` in production.

## Build and run

Requirements: JDK 17+ (a full JDK with `javac`) and the Android SDK (platform 35, build tools 35).
Android Studio provides both. Without it:

```bash
cd android
echo "sdk.dir=$HOME/Android/Sdk" > local.properties     # if ANDROID_HOME is not set
./gradlew testDebugUnitTest      # JVM unit tests of the API client
./gradlew assembleDebug          # app/build/outputs/apk/debug/app-debug.apk
./gradlew installDebug           # on a connected device / running emulator
```

Start the server so that the device can reach it:

* Emulator: the host's `127.0.0.1` is `10.0.2.2`, so enter `http://10.0.2.2:8080`.
* Phone on the LAN: start the server with `"bindAddress": "0.0.0.0"` and enter `http://<pc-ip>:8080`.

A release build (`./gradlew assembleRelease`) needs a signing config (`signingConfigs` in
`app/build.gradle.kts` or Android Studio *Build → Generate Signed App Bundle*).

## Layout

```
android/app/src/main/java/neko/eam/mobile/
├── data/      EamApi (OkHttp: auth, REST, OData, CSRF), Model (DTOs, JSON helpers, ValueCodec),
│              PersistentCookieJar, Session (server, meta model, signed-in user)
└── ui/        Navigation, Connect, Home, List, Detail, Edit (generated form + reference picker),
               Search, Notifications, Theme, Common (load state, errors, avatars)
```

Texts: `res/values/strings.xml` (English), `res/values-de/strings.xml` (German). Field labels come from the
server's meta model.
