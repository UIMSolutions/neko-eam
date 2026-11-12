/// Caller context of an HTTP request: authenticated principal -> access subject -> tenant -> checked use cases.
///
/// The subject and the tenant are stored per request (vibe.d task local) by the route guard / OData handler,
/// so that the REST interface, the web cockpit, transfer and system routes can ask for "the use cases of the
/// current caller in the current tenant".
module neko.eam.presentation.http.access;

import vibe.core.task : TaskLocal;
import vibe.http.server : HTTPServerRequest;
import neko.eam.ports.usecases;
import neko.eam.domain.entities.tenant : defaultTenantId;
import neko.eam.infrastructure.security;

/// Cookie that selects the repository user to act as - honoured only without XSUAA (local development).
enum devUserCookie = "eam-dev-user";
/// Tenant selection by API clients (header) and the Fiori app (cookie). A tenant mapped to the caller's
/// identity zone always wins; entering another tenant needs a user there or a system administrator.
enum tenantHeader = "X-EAM-Tenant";
enum tenantCookie = "eam-tenant";

private TaskLocal!AccessSubjectDto s_subject;
private TaskLocal!bool s_hasSubject;
private TaskLocal!string s_tenant;
private IEamPlatform t_platform; // per server thread, set by `configureAccess`

void configureAccess(IEamPlatform platform) { t_platform = platform; }

IEamPlatform platform() { return t_platform; }

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
AccessSubjectDto establishSubject(HTTPServerRequest req, Authenticator auth) {
	auto principal = auth.authenticate(req.headers.get("Authorization", ""), false);
	auto s = subjectOf(principal, auth.enabled, auth.enabled ? "" : req.cookies.get(devUserCookie, ""));
	auto requested = req.headers.get(tenantHeader, req.cookies.get(tenantCookie, ""));
	s_tenant = t_platform is null ? defaultTenantId : t_platform.resolveTenant(s, requested);
	s_subject = s;
	s_hasSubject = true;
	return s;
}

/// The caller of the current request (administrator outside of a request, e.g. background workers).
AccessSubjectDto currentSubject() {
	return s_hasSubject ? s_subject : AccessSubjectDto(localUserName(), "", true, true, "");
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
