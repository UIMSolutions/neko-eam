/// vibe.d REST interfaces of the backend (JSON in, JSON out) - one interface plus service class per area:
///
/// | Module          | Interface            | Routes (all under /api/v1)                                   |
/// |-----------------|----------------------|--------------------------------------------------------------|
/// | `eamapi`        | `IEamRestApi`        | analysis/*, model, search, me, admin/seed                     |
/// | `notifications` | `INotificationsApi`  | notifications, notifications/read, notifications/dismiss      |
/// | `comments`      | `ICommentsApi`       | comments/{set}/{id}, comments/{commentId}                     |
/// | `reports`       | `IReportsApi`        | reports/{id}/run, reports/run, reportbooks/{id}/run           |
/// | `tenants`       | `ITenantsApi`        | tenants, tenants/{id}                                         |
/// | `backups`       | `IBackupsApi`        | backups, backups/{id}, backups/{id}/restore                   |
/// | `passwords`     | `IPasswordsApi`      | me/password, users/{userName}/password                        |
///
/// The interfaces only talk to the driving ports (`IEamUseCases`, `IEamPlatform`). Authentication, tenant and
/// CSRF check happen in the route guard of `/api/*` before (see `presentation.http`); errors are answered in the
/// OData style `{"error": {code, message, target}}` (see `support.restSettings`). The same interfaces give
/// typed clients: `new RestInterfaceClient!ICommentsApi("http://host:8080/")`.
///
/// Routes that move files (CSV / XLSX / PDF exports, backup download / upload, ArchiMate) or set cookies
/// (sign-in) stay raw router handlers in `presentation.http`.
module neko.eam.presentation.rest;

public import neko.eam.presentation.rest.support;
public import neko.eam.presentation.rest.eamapi;
public import neko.eam.presentation.rest.notifications;
public import neko.eam.presentation.rest.comments;
public import neko.eam.presentation.rest.reports;
public import neko.eam.presentation.rest.tenants;
public import neko.eam.presentation.rest.backups;
public import neko.eam.presentation.rest.passwords;

import vibe.http.router : URLRouter;
import vibe.web.rest : registerRestInterface;
import neko.eam.infrastructure.security : Authenticator;
import neko.eam.ports.usecases;

/// Registers all REST interfaces. `uc` reaches the tenant of the current request; register after the guard.
void registerRestApis(URLRouter router, IEamUseCases uc, Authenticator auth, IEamPlatform platform) {
	auto settings = restSettings();
	router.any("/api/*", &rejectMalformedJson);
	router.registerRestInterface(new EamRestApi(uc, auth, platform), settings);
	router.registerRestInterface(new NotificationsApi(uc), settings);
	router.registerRestInterface(new CommentsApi(uc), settings);
	router.registerRestInterface(new ReportsApi(uc), settings);
	router.registerRestInterface(new PasswordsApi(uc, auth), settings);
	if (platform !is null) {
		router.registerRestInterface(new TenantsApi(platform), settings);
		router.registerRestInterface(new BackupsApi(platform), settings);
	}
}

// every interface also yields a typed client (route and parameter mapping are checked at compile time)
unittest {
	import vibe.web.rest : RestInterfaceClient;
	static foreach (I; AliasSeq!(IEamRestApi, INotificationsApi, ICommentsApi, IReportsApi, ITenantsApi, IBackupsApi, IPasswordsApi))
		static assert(__traits(compiles, new RestInterfaceClient!I("http://127.0.0.1:8080/")), I.stringof);
}

private import std.meta : AliasSeq;
