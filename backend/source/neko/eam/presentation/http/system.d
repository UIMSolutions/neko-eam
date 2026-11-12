/// HTTP endpoints of the platform level: tenants (Mandanten), backup and restore.
///
///   GET    /api/v1/tenants                         tenants (system administrator)
///   POST   /api/v1/tenants                         create  {tenant: {...}, seedDemoData, adminUserName, adminEmail}
///   PATCH  /api/v1/tenants/{id}                    change name, description, status, zoneId
///   DELETE /api/v1/tenants/{id}                    final backup, then remove the tenant and its data
///   GET    /api/v1/backups                         backups of the current tenant (tenant administrator)
///   POST   /api/v1/backups                         create  {comment}
///   GET    /api/v1/backups/{id}                    download the backup file
///   DELETE /api/v1/backups/{id}
///   POST   /api/v1/backups/{id}/restore[?check=true]
///   POST   /api/v1/backups/restore[?check=true&keep=false]   restore an uploaded backup file (raw body)
///
/// The current tenant comes from the request (zone, header X-EAM-Tenant or cookie eam-tenant).
module neko.eam.presentation.http.system;

import std.datetime : Clock;
import vibe.data.json;
import vibe.http.router : URLRouter;
import vibe.http.server;
import vibe.stream.operations : readAll;
import neko.eam.domain.exceptions : ValidationException;
import neko.eam.ports.usecases;
import neko.eam.presentation.http.access;
import neko.eam.presentation.http.errors;
import neko.eam.presentation.http.jsoncodec;

/// Largest accepted backup upload.
enum maxBackupUploadBytes = 256 * 1024 * 1024;

void registerSystemRoutes(URLRouter router, IEamPlatform platform) {
	router.get("/api/v1/tenants", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () => sendJson(res, serializeToJson(platform.listTenants(currentSubject()))));
	});
	router.post("/api/v1/tenants", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () {
			auto body = req.json;
			TenantCreateDto request;
			auto t = body["tenant"].type == Json.Type.object ? body["tenant"] : body;
			static foreach (f; ["id", "name", "description", "status", "zoneId"])
				__traits(getMember, request.tenant, f) = t[f].opt!string(__traits(getMember, request.tenant, f));
			request.seedDemoData = body["seedDemoData"].opt!bool(false);
			request.adminUserName = body["adminUserName"].opt!string("");
			request.adminEmail = body["adminEmail"].opt!string("");
			res.statusCode = HTTPStatus.created;
			sendJson(res, serializeToJson(platform.createTenant(request, currentSubject())));
		});
	});
	router.patch("/api/v1/tenants/:id", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () {
			auto current = platform.getTenant(req.params["id"], currentSubject());
			auto body = req.json;
			static foreach (f; ["name", "description", "status", "zoneId"])
				if (body[f].type == Json.Type.string) __traits(getMember, current, f) = body[f].get!string;
			sendJson(res, serializeToJson(platform.updateTenant(req.params["id"], current, currentSubject())));
		});
	});
	router.delete_("/api/v1/tenants/:id", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () { platform.deleteTenant(req.params["id"], currentSubject()); res.writeVoidBody(); });
	});

	router.get("/api/v1/backups", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () => sendJson(res, serializeToJson(platform.listBackups(currentTenant(), currentSubject()))));
	});
	router.post("/api/v1/backups/restore", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () {
			auto data = req.bodyReader.readAll(maxBackupUploadBytes);
			if (data.length == 0) throw new ValidationException("file", "No backup file uploaded (send it as request body)");
			sendJson(res, serializeToJson(platform.restoreUpload(currentTenant(), data, flag(req, "check"),
				req.query.get("keep", "true") != "false", currentSubject())));
		});
	});
	router.post("/api/v1/backups", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () {
			string comment;
			try comment = req.json["comment"].opt!string(""); catch (Exception) {}
			res.statusCode = HTTPStatus.created;
			sendJson(res, serializeToJson(platform.createBackup(currentTenant(), comment, currentSubject())));
		});
	});
	router.get("/api/v1/backups/:id", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () {
			auto file = platform.backupFile(currentTenant(), req.params["id"], currentSubject());
			res.headers["Content-Disposition"] = `attachment; filename="eam-` ~ currentTenant() ~ "-" ~ req.params["id"] ~ `.eambackup"`;
			res.headers["Cache-Control"] = "no-store";
			res.writeBody(file, "application/octet-stream");
		});
	});
	router.delete_("/api/v1/backups/:id", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () { platform.deleteBackup(currentTenant(), req.params["id"], currentSubject()); res.writeVoidBody(); });
	});
	router.post("/api/v1/backups/:id/restore", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () => sendJson(res, serializeToJson(platform.restoreBackup(currentTenant(), req.params["id"],
			flag(req, "check"), currentSubject()))));
	});
}

private bool flag(HTTPServerRequest req, string name) {
	auto v = req.query.get(name, "false");
	return v == "true" || v == "1";
}
