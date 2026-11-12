/// XSUAA / JWT authentication & scope based authorization.
module neko.eam.infrastructure.security;

public import neko.eam.infrastructure.security.jwt;
import std.algorithm : canFind, endsWith, startsWith;
import neko.eam.infrastructure.configuration;

class AuthenticationException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) @safe pure nothrow { super(msg, file, line); }
}

class AuthorizationException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) @safe pure nothrow { super(msg, file, line); }
}

/// The authenticated caller.
struct Principal {
	string name = "anonymous";
	string[] scopes;
	string givenName;
	string familyName;
	string email;
	string zoneId; /// XSUAA identity zone (subaccount) - selects the tenant mapped to it
}

/// XSUAA scope check independent of the xsappname prefix ("Admin", "neko-eam!t1.Admin").
bool hasScope(const Principal p, string name) {
	foreach (s; p.scopes) if (s == name || s.endsWith("." ~ name)) return true;
	return false;
}

/// Name of the local operating system user (developer mode, CLI, desktop GUI).
string localUserName() {
	import std.process : environment;
	auto n = environment.get("USER", environment.get("USERNAME", ""));
	return n.length ? n : "local-developer";
}

/// Checks bearer tokens: every API call needs `<xsappname>.Display` or `<xsappname>.Admin`.
/// What a caller may read or change is decided by the repository permissions (application layer);
/// holders of `<xsappname>.Admin` are administrators that bypass them (break-glass, initial set-up).
class Authenticator {
	private AppConfig _cfg;

	this(AppConfig cfg) { _cfg = cfg; }

	bool enabled() const { return _cfg.authMode == "xsuaa"; }

	Principal authenticate(string authorizationHeader, bool write) {
		if (!enabled) return Principal(localUserName(), ["Display", "Admin", "SystemAdmin"], "", "", "");
		if (!authorizationHeader.startsWith("Bearer "))
			throw new AuthenticationException("Missing bearer token");
		JwtToken token;
		try {
			token = decodeJwt(authorizationHeader["Bearer ".length .. $]);
			verifyJwt(token, _cfg.xsuaa.verificationkey, _cfg.xsuaa.clientid);
		} catch (TokenException e) throw new AuthenticationException(e.msg);
		auto scopes = token.scopes;
		if (!scopes.canFind(_cfg.xsuaa.xsappname ~ ".Display") && !scopes.canFind(_cfg.xsuaa.xsappname ~ ".Admin")
				&& !scopes.canFind(_cfg.xsuaa.xsappname ~ ".SystemAdmin"))
			throw new AuthorizationException("Missing scope " ~ _cfg.xsuaa.xsappname ~ ".Display");
		return Principal(token.subject, scopes, token.claim("given_name"), token.claim("family_name"), token.claim("email"),
			token.claim("zid"));
	}
}

unittest {
	AppConfig cfg;
	auto auth = new Authenticator(cfg);
	assert(auth.authenticate("", true).name == localUserName());
	cfg.authMode = "xsuaa";
	auth = new Authenticator(cfg);
	bool failed;
	try auth.authenticate("", false); catch (AuthenticationException) failed = true;
	assert(failed);
}
