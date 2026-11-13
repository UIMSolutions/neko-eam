/// Caller context of an HTTP request: authenticated principal -> access subject -> tenant -> checked use cases.
///
/// The principal, the subject and the tenant are stored per request (vibe.d task local) by the route guard /
/// OData handler, so that the REST interface, the web cockpit, transfer and system routes can ask for "the use
/// cases of the current caller in the current tenant".
///
/// With `authMode=local` the caller comes from the sign-in session (cookie `eam-session`, see
/// `presentation.http.login`); modifying requests then need the session's CSRF token (header `X-CSRF-Token`,
/// fetched with `X-CSRF-Token: Fetch` like with the SAP approuter).
module neko.eam.presentation.http.access;

import core.time : minutes;
import std.string : toLower;
import vibe.core.task : TaskLocal;
import vibe.http.common : HTTPMethod;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import neko.eam.ports.usecases;
import neko.eam.domain.entities.tenant : defaultTenantId;
import neko.eam.infrastructure.security;

/// Cookie that selects the repository user to act as - honoured only with `authMode=none` (local development).
enum devUserCookie = "eam-dev-user";
/// Tenant selection by API clients (header) and the Fiori app (cookie). A tenant mapped to the caller's
/// identity zone always wins; entering another tenant needs a user there or a system administrator.
enum tenantHeader = "X-EAM-Tenant";
enum tenantCookie = "eam-tenant";
/// Session id of the local sign-in (HttpOnly, SameSite=Strict, Secure with TLS).
enum sessionCookie = "eam-session";
/// CSRF token header (same protocol as the SAP approuter: "Fetch" -> token, "Required" on rejection).
enum csrfHeader = "X-CSRF-Token";
/// Marks a request the browser app sends on its own (notification polling): with the local sign-in it does not
/// restart the session's idle timer. Only honoured for GET.
enum backgroundHeader = "X-EAM-Background";
/// Set on 401 responses of the local sign-in: page the browser app should open to sign in.
enum loginHeader = "X-EAM-Login";
/// The sign-in page (relative to the server root).
enum loginPage = "login.html";

private TaskLocal!AccessSubjectDto s_subject;
private TaskLocal!Principal s_principal;
private TaskLocal!bool s_hasSubject;
private TaskLocal!string s_tenant;
private TaskLocal!string s_sessionId;
private IEamPlatform t_platform;       // per server thread, set by `configureAccess`
private LoginSessionStore t_sessions;  // per server thread (local sign-in)

void configureAccess(IEamPlatform platform, Authenticator auth = null) {
	t_platform = platform;
	auto idle = auth is null ? 60 : auth.sessionTimeoutMinutes;
	t_sessions = new LoginSessionStore(idle.minutes);
}

IEamPlatform platform() { return t_platform; }

/// Sessions of the local sign-in of this server thread.
LoginSessionStore loginSessions() {
	if (t_sessions is null) t_sessions = new LoginSessionStore;
	return t_sessions;
}

/// The access subject of an authenticated principal (local mode: OS user is (system) administrator unless
/// a repository user is impersonated via the dev cookie).
AccessSubjectDto subjectOf(Principal principal, bool xsuaa, string devUser) {
	if (xsuaa)
		return AccessSubjectDto(principal.name, principal.email, principal.hasScope("Admin"),
			principal.hasScope("SystemAdmin"), principal.zoneId);
	if (devUser.length) return AccessSubjectDto(devUser, "", false, false, "");
	return AccessSubjectDto(principal.name, principal.email, true, true, "");
}

/// Authenticates the request, resolves its tenant and remembers both for the rest of the request.
/// `res` receives the CSRF token / sign-in hint headers of the local sign-in (may be null).
AccessSubjectDto establishSubject(HTTPServerRequest req, HTTPServerResponse res, Authenticator auth) {
	Principal principal;
	AccessSubjectDto s;
	string requested = req.headers.get(tenantHeader, req.cookies.get(tenantCookie, ""));
	if (auth.local) {
		auto sid = req.cookies.get(sessionCookie, "");
		auto background = req.method == HTTPMethod.GET && req.headers.get(backgroundHeader, "") == "1";
		auto session = background ? loginSessions.peek(sid) : loginSessions.touch(sid);
		if (session is null) {
			if (res !is null) res.headers[loginHeader] = loginPage;
			throw new AuthenticationException("Not signed in or the session has expired");
		}
		enforceCsrf(req, res, session.csrfToken);
		principal = Principal(session.userName, session.administrator ? ["Admin", "SystemAdmin"] : [],
			session.displayName, "", session.email, "");
		s = AccessSubjectDto(session.userName, session.email, session.administrator, session.systemAdministrator, "");
		// users and passwords belong to one tenant: only the built-in administrator may switch
		if (!session.systemAdministrator) requested = session.tenant;
		s_sessionId = session.id;
	} else {
		principal = auth.authenticate(req.headers.get("Authorization", ""), false);
		s = subjectOf(principal, auth.xsuaa, auth.open ? req.cookies.get(devUserCookie, "") : "");
		s_sessionId = "";
	}
	s_tenant = t_platform is null ? defaultTenantId : t_platform.resolveTenant(s, requested);
	s_subject = s;
	s_principal = principal;
	s_hasSubject = true;
	return s;
}

/// Hands out the session's CSRF token on request and rejects modifying requests without it.
private void enforceCsrf(HTTPServerRequest req, HTTPServerResponse res, string token) {
	auto sent = req.headers.get(csrfHeader, "");
	if (sent.toLower == "fetch" && res !is null) res.headers[csrfHeader] = token;
	if (req.method == HTTPMethod.GET || req.method == HTTPMethod.HEAD || req.method == HTTPMethod.OPTIONS) return;
	if (!constantTimeEquals(cast(const(ubyte)[]) sent, cast(const(ubyte)[]) token)) {
		if (res !is null) res.headers[csrfHeader] = "Required";
		throw new AuthorizationException("CSRF token validation failed");
	}
}

/// The caller of the current request (administrator outside of a request, e.g. background workers).
AccessSubjectDto currentSubject() {
	return s_hasSubject ? s_subject : AccessSubjectDto(localUserName(), "", true, true, "");
}

/// The authenticated principal of the current request (profile data for the shell bar).
Principal currentPrincipal() {
	return s_hasSubject ? s_principal : Authenticator.localOperator();
}

/// The live sign-in session of the current request (null without local sign-in).
LoginSession* currentSession() {
	auto id = s_sessionId.storage;
	return id.length ? loginSessions.touch(id) : null;
}

/// The tenant of the current request (default tenant outside of a request).
string currentTenant() {
	string t = s_tenant.storage;
	return t.length ? t : defaultTenantId;
}

/// The use cases as the current caller may use them (in the current tenant).
IEamUseCases callerUseCases(IEamUseCases uc) {
	return uc.access.useCasesFor(currentSubject());
}
