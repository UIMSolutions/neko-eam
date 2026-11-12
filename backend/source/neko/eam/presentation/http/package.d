/// HTTP listener composition: health, sign-in, OData, REST, web cockpit, ArchiMate export and static Fiori frontend.
module neko.eam.presentation.http;

public import neko.eam.presentation.http.jsoncodec;
public import neko.eam.presentation.http.errors;
public import neko.eam.presentation.http.transfer;
public import neko.eam.presentation.http.access;
public import neko.eam.presentation.http.system;
public import neko.eam.presentation.http.reports;
public import neko.eam.presentation.http.comments;
public import neko.eam.presentation.http.login;

import std.algorithm : startsWith;
import std.file : exists;
import vibe.data.json;
import vibe.http.fileserver : serveStaticFiles;
import vibe.http.router : URLRouter;
import vibe.http.server;
import vibe.stream.tls : createTLSContext, TLSContextKind;
import vibe.textfilter.urlencode : urlEncode;
import vibe.web.rest : registerRestInterface, RestInterfaceSettings;
import neko.eam.ports.usecases;
import neko.eam.domain.exceptions : AccessDeniedException;
import neko.eam.application.services.tenantrouting : TenantRoutingUseCases;
import neko.eam.infrastructure.configuration;
import neko.eam.infrastructure.logging;
import neko.eam.infrastructure.security;
import neko.eam.presentation.odata.service;
import neko.eam.presentation.rest;
import neko.eam.presentation.web;

URLRouter buildRouter(AppConfig cfg, IEamPlatform platform, Authenticator auth) {
	auto router = new URLRouter;
	configureAccess(platform, auth);
	// every adapter works with "the" use cases; each call reaches the tenant of the current request
	IEamUseCases uc = new TenantRoutingUseCases(() => platform.tenantUseCases(currentTenant()));

	router.get("/health", (HTTPServerRequest req, HTTPServerResponse res) {
		res.writeJsonBody(["status": "UP", "service": "neko-eam"]);
	});
	// sign-in / sign-out of the login and logout views (public)
	registerLoginRoutes(router, platform, auth);

	// authentication for all API and cockpit routes; the caller is remembered for the request and every
	// use case call is checked against the caller's permissions (users / roles / permissions)
	void guard(HTTPServerRequest req, HTTPServerResponse res) {
		try establishSubject(req, res, auth);
		catch (AuthenticationException e) {
			// the server-rendered cockpit sends the browser to the login view, API clients get 401
			if (auth.local && req.requestPath.toString.startsWith("/web"))
				return res.redirect("/" ~ loginPage ~ "?returnTo=" ~ urlEncode(req.requestURI));
			throw new HTTPStatusException(HTTPStatus.unauthorized, e.msg);
		}
		catch (AuthorizationException e) throw new HTTPStatusException(HTTPStatus.forbidden, e.msg);
		catch (AccessDeniedException e) throw new HTTPStatusException(HTTPStatus.forbidden, e.msg);
	}
	router.any("/api/*", &guard);
	router.any("/web*", &guard);

	new ODataService(uc, auth, cfg.odataBasePath).register(router);

	router.get("/api/v1/export/archimate", (HTTPServerRequest req, HTTPServerResponse res) {
		string xml;
		try xml = callerUseCases(uc).archimate.exportModel();
		catch (Exception e) throw new HTTPStatusException(classify(e).status, e.msg);
		res.headers["Content-Disposition"] = `attachment; filename="eam-archimate.xml"`;
		res.writeBody(xml, "application/xml");
	});
	registerTransferRoutes(router, uc, auth);
	registerSystemRoutes(router, platform);
	registerReportRoutes(router, uc);
	registerCommentRoutes(router, uc);
	registerPasswordRoutes(router, uc, auth);
	registerRestInterface(router, new EamRestApi(uc, auth, platform));
	new WebCockpit(uc).register(router);

	if (exists(cfg.frontendPath)) {
		router.get("/", staticRedirect("/index.html"));
		if (auth.local) // signed out: straight to the login view instead of an app without data
			router.get("/index.html", (HTTPServerRequest req, HTTPServerResponse res) {
				if (loginSessions.touch(req.cookies.get(sessionCookie, "")) is null) res.redirect(loginPage);
			});
		router.get("*", serveStaticFiles(cfg.frontendPath));
	} else
		logWarn("Frontend path '%s' not found - Fiori app is not served", cfg.frontendPath);
	return router;
}

HTTPListener startHttpServer(AppConfig cfg, IEamPlatform platform, Authenticator auth) {
	auto settings = new HTTPServerSettings;
	settings.port = cfg.port;
	settings.bindAddresses = [cfg.bindAddress];
	settings.errorPageHandler = (HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo err) @safe {
		res.writeJsonBody(["error": ["code": "HttpError", "message": err.message]]);
	};
	settings.serverString = "neko-eam"; // no framework version in the Server header
	if (cfg.tlsCertificateFile.length && cfg.tlsPrivateKeyFile.length) {
		settings.tlsContext = createTLSContext(TLSContextKind.server);
		settings.tlsContext.useCertificateChainFile(cfg.tlsCertificateFile);
		settings.tlsContext.usePrivateKeyFile(cfg.tlsPrivateKeyFile);
	}
	// largest request body: backup uploads (CSV / XLSX uploads are limited to `maxUploadBytes` by their routes)
	static assert(maxBackupUploadBytes >= maxUploadBytes);
	settings.maxRequestSize = maxBackupUploadBytes + 1024 * 1024;
	auto listener = listenHTTP(settings, buildRouter(cfg, platform, auth));
	logInfo("Neko EAM listening on %s://%s:%s (OData: %s/, auth: %s)",
		settings.tlsContext ? "https" : "http", cfg.bindAddress, cfg.port, cfg.odataBasePath, cfg.authMode);
	return listener;
}
