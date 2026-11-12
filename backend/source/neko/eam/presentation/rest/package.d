/// vibe.d REST interface for analysis, reporting, meta model and user info
/// (consumed by the Fiori shell, dashboard and integrations).
module neko.eam.presentation.rest;

import std.algorithm : canFind, endsWith;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import vibe.http.common : HTTPStatusException, HTTPMethod;
import vibe.web.rest;
import neko.eam.ports.usecases;
import neko.eam.infrastructure.security;
import neko.eam.presentation.http.errors;
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
}

struct DevUserDto {
	string userName;
	string name;
}

@path("/api/v1")
interface IEamRestApi {
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
	@headerParam("authorization", "Authorization")
	UserInfoDto getMe(string authorization = "") @safe;

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

	PortfolioReportDto getPortfolio() @trusted { return guarded(() => uc.analysis.portfolio()); }
	ImpactReportDto getImpact(string _id) @trusted { return guarded(() => uc.analysis.impact(_id)); }
	CapabilityCoverageDto[] getCoverage() @trusted { return guarded(() => uc.analysis.coverage()); }
	TechnologyRiskDto[] getRisks() @trusted { return guarded(() => uc.analysis.technologyRisks()); }
	ProductAlertDto[] getProductAlerts() @trusted { return guarded(() => uc.analysis.productAlerts()); }

	/// The use cases as the caller of the current request may use them.
	private IEamUseCases uc() { return callerUseCases(_uc); }
	EntitySetInfoDto[] getModel() @trusted { return describeModel(); }
	SearchHitDto[] getSearch(string q, int top = 20) @trusted {
		if (top < 1 || top > 200) throw new HTTPStatusException(400, "top must be between 1 and 200");
		return guarded(() => uc.search.search(q, top));
	}
	size_t postSeed() @trusted { return guarded(() => uc.seeder.seed()); }

	UserInfoDto getMe(string authorization = "") @trusted {
		// the route guard already authenticated the request; this only extracts the profile
		auto p = guarded(() => _auth.authenticate(authorization, false));
		auto u = toUserInfo(p, _auth.enabled ? "xsuaa" : "none");
		auto subject = currentSubject();
		applyRights(u, guarded(() => _uc.access.rightsFor(subject)));
		u.systemAdministrator = subject.systemAdministrator;
		if (_platform !is null) {
			auto tenantId = currentTenant();
			u.tenants = guarded(() => _platform.tenantsFor(subject));
			u.tenant = TenantRefDto(tenantId, tenantId);
			foreach (t; u.tenants) if (t.id == tenantId) u.tenant = t;
			u.canBackup = guarded(() => _platform.canBackup(tenantId, subject));
		}
		if (!_auth.enabled) {
			// local development: offer the repository users for "act as" (never with XSUAA)
			auto users = guarded(() => _uc.users.list);
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

	/// Translates business exceptions into HTTP status codes.
	private static T guarded(T)(scope T delegate() fn) {
		try return fn();
		catch (HTTPStatusException e) throw e;
		catch (AuthenticationException e) throw new HTTPStatusException(401, e.msg);
		catch (AuthorizationException e) throw new HTTPStatusException(403, e.msg);
		catch (Exception e) {
			auto info = classify(e);
			throw new HTTPStatusException(info.status, info.status >= 500 ? "Internal server error" : e.msg);
		}
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
	import std.ascii : toUpper;
	import std.array : split;
	UserInfoDto u;
	u.name = p.name;
	u.email = p.email;
	u.authMode = authMode;
	u.displayName = (p.givenName.length || p.familyName.length) ? (p.givenName ~ " " ~ p.familyName) : p.name;
	string initials;
	foreach (part; u.displayName.split!(c => c == ' ' || c == '.' || c == '_' || c == '-' || c == '@'))
		if (part.length && initials.length < 2) initials ~= toUpper(part[0]);
	u.initials = initials.length ? initials : "?";
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
