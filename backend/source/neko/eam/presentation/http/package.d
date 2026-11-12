/// HTTP listener composition: health, OData, REST, web cockpit, ArchiMate export and static Fiori frontend.
module neko.eam.presentation.http;

public import neko.eam.presentation.http.jsoncodec;
public import neko.eam.presentation.http.errors;
public import neko.eam.presentation.http.transfer;
public import neko.eam.presentation.http.access;
public import neko.eam.presentation.http.system;
public import neko.eam.presentation.http.reports;
public import neko.eam.presentation.http.comments;

import std.file : exists;
import vibe.data.json;
import vibe.http.fileserver : serveStaticFiles;
import vibe.http.router : URLRouter;
import vibe.http.server;
import vibe.stream.tls : createTLSContext, TLSContextKind;
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
	configureAccess(platform);
	// every adapter works with "the" use cases; each call reaches the tenant of the current request
	IEamUseCases uc = new TenantRoutingUseCases(() => platform.tenantUseCases(currentTenant()));

	router.get("/health", (HTTPServerRequest req, HTTPServerResponse res) {
		res.writeJsonBody(["status": "UP", "service": "neko-eam"]);
	});

	// authentication for all API and cockpit routes; the caller is remembered for the request and every
	// use case call is checked against the caller's permissions (users / roles / permissions)
	void guard(HTTPServerRequest req, HTTPServerResponse res) {
		try establishSubject(req, auth);
		catch (AuthenticationException e) throw new HTTPStatusException(HTTPStatus.unauthorized, e.msg);
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
	registerRestInterface(router, new EamRestApi(uc, auth, platform));
	new WebCockpit(uc).register(router);

	if (exists(cfg.frontendPath)) {
		router.get("/", staticRedirect("/index.html"));
		router.get("*", serveStaticFiles(cfg.frontendPath));
	} else
		logWarn("Frontend path '%s' not found - Fiori app is not served", cfg.frontendPath);
	return router;
}

HTTPListener startHttpServer(AppConfig cfg, IEamPlatform platform, Authenticator auth) {
	auto settings = new HTTPServerSettings;
	settings.port = cfg.port;
	settings.bindAddresses = [cfg.bindAddress];
	settings.maxRequestSize = maxUploadBytes + 1024 * 1024; // CSV / XLSX uploads
	settings.errorPageHandler = (HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo err) @safe {
		res.writeJsonBody(["error": ["code": "HttpError", "message": err.message]]);
	};
	if (cfg.tlsCertificateFile.length && cfg.tlsPrivateKeyFile.length) {
		settings.tlsContext = createTLSContext(TLSContextKind.server);
		settings.tlsContext.useCertificateChainFile(cfg.tlsCertificateFile);
		settings.tlsContext.usePrivateKeyFile(cfg.tlsPrivateKeyFile);
	}
	settings.maxRequestSize = maxBackupUploadBytes + 1024 * 1024; // backup uploads (CSV / XLSX are smaller)
	auto listener = listenHTTP(settings, buildRouter(cfg, platform, auth));
	logInfo("Neko EAM listening on %s://%s:%s (OData: %s/, auth: %s)",
		settings.tlsContext ? "https" : "http", cfg.bindAddress, cfg.port, cfg.odataBasePath, cfg.authMode);
	return listener;
}
