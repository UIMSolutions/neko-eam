/// REST interface of the core repository functions: analyses, meta model, central search, signed-in user
/// and demo data (consumed by the Fiori shell, dashboard, Android app and integrations).
///
///   GET  /api/v1/analysis/portfolio | impact/{id} | coverage | risks | products
///   GET  /api/v1/model                 meta model (sets, fields, labels, types, references, value lists)
///   GET  /api/v1/search?q=&top=        central search (top 1-200)
///   GET  /api/v1/me                    signed-in user, rights, tenant(s)
///   POST /api/v1/admin/seed            demo data
module neko.eam.presentation.rest.eamapi;

import std.algorithm : canFind, endsWith;
import std.string : strip;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import vibe.http.common : HTTPStatusException, HTTPMethod;
import vibe.web.rest;
import neko.eam.ports.usecases;
import neko.eam.infrastructure.security;
import neko.eam.domain.exceptions : ValidationException;
import neko.eam.presentation.http.access;

/// The signed in user as shown in the Fiori shell bar profile.
struct UserInfoDto {
	string name;
	string displayName;
	string initials;
	string email;
	string[] roles;
	bool canEdit;
	string authMode;
	/// Effective rights from the users / roles / permissions of the repository.
	AccessRightsDto access;
	/// Current tenant (Mandant) and the tenants the user may switch to.
	TenantRefDto tenant;
	TenantRefDto[] tenants;
	bool systemAdministrator;
	bool canBackup;
	/// Local development only: repository users that can be impersonated (cookie `eam-dev-user`).
	DevUserDto[] devUsers;
	string actingAs;
	/// Local sign-in: the user can change the own password / should do so now (set by an administrator).
	bool passwordChangeable;
	bool mustChangePassword;
}

struct DevUserDto {
	string userName;
	string name;
}

@path("/api/v1")
interface IEamRestApi {
	// all methods are @safe (vibe.d 0.10); the implementation is @trusted around the use case calls
	@method(HTTPMethod.GET) @path("/analysis/portfolio")
	PortfolioReportDto getPortfolio() @safe;

	@method(HTTPMethod.GET) @path("/analysis/impact/:id")
	ImpactReportDto getImpact(string _id) @safe;

	@method(HTTPMethod.GET) @path("/analysis/coverage")
	CapabilityCoverageDto[] getCoverage() @safe;

	@method(HTTPMethod.GET) @path("/analysis/risks")
	TechnologyRiskDto[] getRisks() @safe;

	@method(HTTPMethod.GET) @path("/analysis/products")
	ProductAlertDto[] getProductAlerts() @safe;

	/// Meta model: entity sets, field labels, groups, types, references and enumeration values.
	@method(HTTPMethod.GET) @path("/model")
	EntitySetInfoDto[] getModel() @safe;

	/// Central search over all entity sets (Fiori shell bar search field).
	@method(HTTPMethod.GET) @path("/search")
	SearchHitDto[] getSearch(string q, int top = 20) @safe;

	@method(HTTPMethod.GET) @path("/me")
	UserInfoDto getMe() @safe;

	@method(HTTPMethod.POST) @path("/admin/seed")
	size_t postSeed() @safe;
}

class EamRestApi : IEamRestApi {
	private {
		IEamUseCases _uc;
		Authenticator _auth;
	}

	private IEamPlatform _platform;

	this(IEamUseCases uc, Authenticator auth, IEamPlatform platform = null) { _uc = uc; _auth = auth; _platform = platform; }

	PortfolioReportDto getPortfolio() @trusted { return uc.analysis.portfolio(); }
	ImpactReportDto getImpact(string _id) @trusted { return uc.analysis.impact(_id); }
	CapabilityCoverageDto[] getCoverage() @trusted { return uc.analysis.coverage(); }
	TechnologyRiskDto[] getRisks() @trusted { return uc.analysis.technologyRisks(); }
	ProductAlertDto[] getProductAlerts() @trusted { return uc.analysis.productAlerts(); }

	/// The use cases as the caller of the current request may use them.
	private IEamUseCases uc() { return callerUseCases(_uc); }
	EntitySetInfoDto[] getModel() @trusted { return describeModel(); }
	SearchHitDto[] getSearch(string q, int top = 20) @trusted {
		if (top < 1 || top > 200) throw new ValidationException("top", "top must be between 1 and 200");
		return uc.search.search(q, top);
	}
	size_t postSeed() @trusted { return uc.seeder.seed(); }

	UserInfoDto getMe() @trusted {
		// the route guard authenticated the request and remembered the principal - no second token check
		auto u = toUserInfo(currentPrincipal(), _auth.mode);
		auto subject = currentSubject();
		applyRights(u, _uc.access.rightsFor(subject));
		u.systemAdministrator = subject.systemAdministrator;
		if (_platform !is null) {
			auto tenantId = currentTenant();
			u.tenant = TenantRefDto(tenantId, tenantId);
			u.tenants = _platform.tenantsFor(subject);
			foreach (t; u.tenants) if (t.id == tenantId) u.tenant = t;
			// local sign-in: users and passwords belong to one tenant, only the built-in administrator switches
			if (_auth.local && !subject.systemAdministrator) u.tenants = [u.tenant];
			u.canBackup = _platform.canBackup(tenantId, subject);
		}
		if (_auth.local) {
			if (u.access.displayName.length && u.access.displayName != subject.userName) u.displayName = u.access.displayName;
			u.initials = initialsOf(u.displayName);
			if (auto session = currentSession()) {
				u.passwordChangeable = !session.administrator;
				u.mustChangePassword = session.mustChangePassword;
			}
		}
		if (_auth.open) {
			// local development: offer the repository users for "act as" (never with a real sign-in)
			auto users = _uc.users.list;
			if (users.length) u.devUsers ~= DevUserDto("", "Local administrator");
			foreach (usr; users) if (usr.active) u.devUsers ~= DevUserDto(usr.userName, usr.name);
			if (!subject.administrator) {
				u.actingAs = subject.userName;
				u.name = subject.userName;
				u.displayName = u.access.displayName;
				u.initials = initialsOf(u.displayName);
				u.email = "";
			}
		}
		return u;
	}
}

/// Roles, edit flag and set rights from the repository access control.
void applyRights(ref UserInfoDto u, AccessRightsDto rights) {
	u.access = rights;
	u.roles = rights.unrestricted ? ["Administrator"] : rights.roles.dup;
	u.canEdit = rights.unrestricted || rights.sets.canFind!(s => s.create || s.update || s.remove);
}

string initialsOf(string displayName) {
	import std.ascii : toUpper;
	import std.array : split;
	string initials;
	foreach (part; displayName.split!(c => c == ' ' || c == '.' || c == '_' || c == '-' || c == '@'))
		if (part.length && initials.length < 2) initials ~= toUpper(part[0]);
	return initials.length ? initials : "?";
}

UserInfoDto toUserInfo(Principal p, string authMode) {
	UserInfoDto u;
	u.name = p.name;
	u.email = p.email;
	u.authMode = authMode;
	u.displayName = (p.givenName.length || p.familyName.length) ? (p.givenName ~ " " ~ p.familyName).strip : p.name;
	u.initials = initialsOf(u.displayName);
	foreach (s; p.scopes) {
		if (s.endsWith("Admin") && !u.roles.canFind("Architect")) u.roles ~= "Architect";
		else if (s.endsWith("Display") && !u.roles.canFind("Viewer")) u.roles ~= "Viewer";
	}
	u.canEdit = u.roles.canFind("Architect");
	return u;
}

unittest {
	auto u = toUserInfo(Principal("jdoe", ["eam.Display"], "Jane", "Doe", "jane@example.org"), "xsuaa");
	assert(u.displayName == "Jane Doe" && u.initials == "JD" && u.roles == ["Viewer"] && !u.canEdit);
	assert(toUserInfo(Principal("oz", ["Display", "Admin"]), "none").initials == "O");
	AccessRightsDto r;
	r.roles = ["Viewer"];
	r.sets = [SetRightsDto("Applications", true, false, false, false)];
	applyRights(u, r);
	assert(u.roles == ["Viewer"] && !u.canEdit);
	r.sets[0].update = true;
	applyRights(u, r);
	assert(u.canEdit);
	assert(initialsOf("Julia Becker") == "JB");
}
