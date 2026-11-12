/// Local sign-in (`authMode=local`): sign-in / sign-out endpoints for the login and logout views, and the
/// password management of the repository users.
///
///   GET    /auth/info                         {authMode, signedIn, multiTenant} - drives the login view
///   POST   /auth/login                        {userName, password, tenant?} -> session cookie
///   POST   /auth/logout                       ends the session (any auth mode; no-op without a session)
///   POST   /api/v1/me/password                {currentPassword, newPassword} - change the own password
///   GET    /api/v1/users/{userName}/password  {hasPassword}             (read permission on Users)
///   PUT    /api/v1/users/{userName}/password  {password, mustChange?}   (update permission on Users)
///   DELETE /api/v1/users/{userName}/password  sign-in no longer possible (update permission on Users)
///
/// Failed sign-ins are throttled per user name and per client address; the error never tells whether the
/// user exists. A new session id is issued on every sign-in (no session fixation).
module neko.eam.presentation.http.login;

import core.time : Duration;
import std.conv : to;
import std.string : strip, toLower;
import vibe.data.json;
import vibe.http.common : Cookie;
import vibe.http.router : URLRouter;
import vibe.http.server;
import neko.eam.domain.entities.tenant : defaultTenantId;
import neko.eam.domain.exceptions;
import neko.eam.infrastructure.logging;
import neko.eam.infrastructure.security;
import neko.eam.ports.usecases;
import neko.eam.presentation.http.access;
import neko.eam.presentation.http.errors;

/// Public routes - registered before the guard of `/api/*`.
void registerLoginRoutes(URLRouter router, IEamPlatform platform, Authenticator auth) {
	// per account: few attempts; per client address: more (users behind one NAT share an address)
	auto accounts = new LoginThrottle(5);
	auto clients = new LoginThrottle(20);

	router.get("/auth/info", (HTTPServerRequest req, HTTPServerResponse res) {
		auto info = Json.emptyObject;
		info["authMode"] = auth.mode;
		info["signedIn"] = auth.local && loginSessions.touch(req.cookies.get(sessionCookie, "")) !is null;
		info["multiTenant"] = auth.local && platform !is null && platform.tenantsFor(systemSubject).length > 1;
		res.headers["Cache-Control"] = "no-store";
		res.writeJsonBody(info);
	});

	router.post("/auth/login", (HTTPServerRequest req, HTTPServerResponse res) {
		res.headers["Cache-Control"] = "no-store";
		if (!auth.local)
			return sendError(res, HTTPStatus.badRequest, "NotSupported", "The sign-in form is not used with authMode '" ~ auth.mode ~ "'");
		Json body;
		try body = req.json; catch (Exception) {}
		if (body.type != Json.Type.object) return sendError(res, HTTPStatus.badRequest, "ValidationError", "JSON body expected");
		auto userName = body["userName"].opt!string("").strip;
		auto password = body["password"].opt!string("");
		auto tenant = body["tenant"].opt!string("").strip.toLower;
		if (!userName.length || !password.length)
			return sendError(res, HTTPStatus.badRequest, "ValidationError", "Enter user name and password");
		if (userName.length > 256 || password.length > 1024 || tenant.length > 64)
			return sendError(res, HTTPStatus.badRequest, "ValidationError", "Input too long");
		if (!tenant.length) tenant = defaultTenantId;

		auto client = "ip:" ~ req.clientAddress.toAddressString();
		auto account = "user:" ~ tenant ~ "|" ~ userName.toLower;
		auto wait = maxDuration(clients.lockedFor(client), accounts.lockedFor(account));
		if (wait > Duration.zero) {
			auto secs = wait.total!"seconds" + 1;
			res.headers["Retry-After"] = secs.to!string;
			return sendError(res, HTTPStatus.tooManyRequests, "TooManyAttempts",
				"Too many failed sign-in attempts. Try again in " ~ secs.to!string ~ " seconds.");
		}

		LoginSession data;
		try {
			if (!tenantExists(platform, tenant)) throw new InvalidCredentialsException;
			if (auth.verifyLocalAdmin(userName, password)) {
				data.userName = auth.localAdminUser;
				data.displayName = "Administrator";
				data.administrator = data.systemAdministrator = true;
			} else {
				auto signedIn = platform.tenantUseCases(tenant).access.signIn(userName, password);
				data.userName = signedIn.subject.userName;
				data.email = signedIn.subject.email;
				data.displayName = signedIn.displayName;
				data.mustChangePassword = signedIn.mustChangePassword;
				// suspended tenant, or no user of a non-default tenant
				platform.resolveTenant(signedIn.subject, tenant);
			}
			data.tenant = tenant;
		} catch (InvalidCredentialsException e) {
			clients.failure(client);
			accounts.failure(account);
			logWarn("Failed sign-in of '%s' (tenant %s) from %s", userName, tenant, client[3 .. $]);
			return sendError(res, HTTPStatus.unauthorized, "InvalidCredentials", e.msg);
		} catch (AccessDeniedException e) {
			return sendError(res, HTTPStatus.forbidden, "Forbidden", e.msg);
		}
		accounts.success(account);
		// never continue a session the browser already had (session fixation)
		loginSessions.destroy(req.cookies.get(sessionCookie, ""));
		auto session = loginSessions.create(data);
		setSessionCookie(res, auth, session.id);
		logInfo("Sign-in of '%s' (tenant %s) from %s", data.userName, tenant, client[3 .. $]);
		auto r = Json.emptyObject;
		r["userName"] = data.userName;
		r["displayName"] = data.displayName;
		r["tenant"] = tenant;
		r["mustChangePassword"] = data.mustChangePassword;
		res.writeJsonBody(r);
	});

	router.post("/auth/logout", (HTTPServerRequest req, HTTPServerResponse res) {
		auto id = req.cookies.get(sessionCookie, "");
		if (id.length) {
			if (auto s = loginSessions.touch(id)) logInfo("Sign-out of '%s' (tenant %s)", s.userName, s.tenant);
			loginSessions.destroy(id);
			setSessionCookie(res, auth, null);
		}
		res.headers["Cache-Control"] = "no-store";
		res.writeVoidBody();
	});
}

/// Password routes behind the `/api/*` guard (session, CSRF token and tenant are established).
void registerPasswordRoutes(URLRouter router, IEamUseCases uc, Authenticator auth) {
	router.post("/api/v1/me/password", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () {
			auto session = currentSession();
			if (!auth.local || session is null)
				throw new ValidationException("authMode", "Passwords are only used with the local sign-in");
			if (session.administrator)
				throw new ValidationException("password", "The password of the built-in administrator is set in the server configuration (EAM_ADMIN_PASSWORD)");
			auto body = req.json;
			uc.access.changePassword(session.userName, body["currentPassword"].opt!string(""), body["newPassword"].opt!string(""));
			session.mustChangePassword = false;
			logInfo("Password of '%s' (tenant %s) changed by the user", session.userName, session.tenant);
			// other browsers of the user have to sign in with the new password
			loginSessions.destroyForUser(session.tenant, session.userName, session.id);
			res.writeVoidBody();
		});
	});
	router.get("/api/v1/users/:userName/password", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () {
			callerUseCases(uc).users.count; // read permission on Users
			res.writeJsonBody(["hasPassword": uc.access.hasPassword(req.params["userName"]),
				"localSignIn": auth.local]);
		});
	});
	router.put("/api/v1/users/:userName/password", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () {
			auto body = req.json;
			auto userName = req.params["userName"];
			uc.access.setPassword(userName, body["password"].opt!string(""), currentSubject(), body["mustChange"].opt!bool(true));
			auto keep = currentSession();
			loginSessions.destroyForUser(currentTenant(), userName, keep is null ? null : keep.id);
			logInfo("Password of '%s' (tenant %s) set by '%s'", userName, currentTenant(), currentSubject().userName);
			res.writeVoidBody();
		});
	});
	router.delete_("/api/v1/users/:userName/password", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () {
			auto userName = req.params["userName"];
			uc.access.removePassword(userName, currentSubject());
			loginSessions.destroyForUser(currentTenant(), userName);
			logInfo("Password of '%s' (tenant %s) removed by '%s'", userName, currentTenant(), currentSubject().userName);
			res.writeVoidBody();
		});
	});
}

/// Platform operator used for lookups before anybody is signed in.
private AccessSubjectDto systemSubject() { return AccessSubjectDto("system", "", true, true, ""); }

private bool tenantExists(IEamPlatform platform, string tenant) {
	if (platform is null) return tenant == defaultTenantId;
	foreach (t; platform.tenantsFor(systemSubject)) if (t.id == tenant) return true;
	return false;
}

private void setSessionCookie(HTTPServerResponse res, Authenticator auth, string id) {
	auto c = res.setCookie(sessionCookie, id, "/");
	c.httpOnly = true;
	c.sameSite = Cookie.SameSite.strict;
	c.secure = auth.secureCookies;
	if (id is null) c.maxAge = 0;
}

private Duration maxDuration(Duration a, Duration b) { return a > b ? a : b; }
