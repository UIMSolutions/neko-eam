/// XSUAA / JWT authentication & scope based authorization.
module neko.eam.infrastructure.security;

public import neko.eam.infrastructure.security.jwt;
public import neko.eam.infrastructure.security.password;
public import neko.eam.infrastructure.security.sessions;
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

/// Authentication of the HTTP callers, by `authMode`:
///
/// * `none`  - local development: every request is the OS user (administrator).
/// * `local` - sign-in form with the user name and password of a repository user (server-side session, see
///             `LoginSessionStore`); optionally a built-in administrator from `EAM_ADMIN_PASSWORD`.
/// * `xsuaa` - bearer tokens: every API call needs `<xsappname>.Display`, `.Admin` or `.SystemAdmin`.
///
/// What a caller may read or change is decided by the repository permissions (application layer);
/// holders of `<xsappname>.Admin` are administrators that bypass them (break-glass, initial set-up).
class Authenticator {
	private {
		AppConfig _cfg;
		Pbkdf2PasswordHasher _hasher;
		string _adminHash; /// hash of the built-in local administrator's password ("" = no built-in administrator)
	}

	this(AppConfig cfg) {
		_cfg = cfg;
		_hasher = new Pbkdf2PasswordHasher;
		if (cfg.authMode == AuthMode.local && cfg.localAdminPassword.length)
			_adminHash = cfg.localAdminPassword.startsWith(Pbkdf2PasswordHasher.scheme ~ "$")
				? cfg.localAdminPassword : _hasher.hash(cfg.localAdminPassword);
	}

	string mode() const { return _cfg.authMode; }
	bool xsuaa() const { return _cfg.authMode == AuthMode.xsuaa; }
	/// Sign-in form with repository users (cookie session).
	bool local() const { return _cfg.authMode == AuthMode.local; }
	/// No authentication at all (local development).
	bool open() const { return _cfg.authMode == AuthMode.none; }

	/// Principal of a bearer token (xsuaa) or of the local operator (none). Local sign-in sessions are
	/// resolved by the HTTP adapter and never reach this method.
	Principal authenticate(string authorizationHeader, bool write) {
		if (open) return localOperator();
		if (local) throw new AuthenticationException("Not signed in");
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

	/// The OS user without authentication (authMode none, CLI, desktop).
	static Principal localOperator() {
		return Principal(localUserName(), ["Display", "Admin", "SystemAdmin"], "", "", "");
	}

	/// Name of the built-in administrator of the local sign-in ("" if none is configured).
	string localAdminUser() const { return _adminHash.length ? _cfg.localAdminUser : ""; }

	/// Checks the password of the built-in administrator (constant time; false if none is configured).
	bool verifyLocalAdmin(string userName, string password) {
		import std.string : toLower;
		if (!_adminHash.length) return false;
		auto ok = _hasher.verify(password, _adminHash);
		return ok && userName.toLower == _cfg.localAdminUser.toLower;
	}

	/// Idle timeout of local sign-in sessions.
	uint sessionTimeoutMinutes() const { return _cfg.sessionTimeoutMinutes; }

	/// Session cookies only over HTTPS (TLS configured on this server).
	bool secureCookies() const { return _cfg.tlsCertificateFile.length && _cfg.tlsPrivateKeyFile.length; }
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

	cfg.authMode = "local";
	cfg.localAdminPassword = "Sup3r secret";
	auth = new Authenticator(cfg);
	assert(auth.local && auth.localAdminUser == "admin");
	assert(auth.verifyLocalAdmin("Admin", "Sup3r secret"));
	assert(!auth.verifyLocalAdmin("admin", "wrong") && !auth.verifyLocalAdmin("anna", "Sup3r secret"));
	failed = false;
	try auth.authenticate("Bearer x.y.z", false); catch (AuthenticationException) failed = true;
	assert(failed, "local mode only accepts sessions");
	cfg.localAdminPassword = "";
	assert(!new Authenticator(cfg).verifyLocalAdmin("admin", ""));
}
