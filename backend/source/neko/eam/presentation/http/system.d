/// HTTP endpoints of the backup files (the JSON endpoints of tenants and backups are the REST interfaces
/// `presentation.rest.tenants` and `presentation.rest.backups`):
///
///   GET    /api/v1/backups/{id}                    download the backup file
///   POST   /api/v1/backups/restore[?check=true&keep=false]   restore an uploaded backup file (raw body)
///
/// The current tenant comes from the request (zone, header X-EAM-Tenant or cookie eam-tenant).
module neko.eam.presentation.http.system;

import vibe.data.json;
import vibe.http.router : URLRouter;
import vibe.http.server;
import vibe.stream.operations : readAll;
import neko.eam.domain.exceptions : ValidationException;
import neko.eam.ports.usecases;
import neko.eam.presentation.http.access;
import neko.eam.presentation.http.errors;
import neko.eam.presentation.rest.support : flag;

/// Largest accepted backup upload.
enum maxBackupUploadBytes = 256 * 1024 * 1024;

void registerBackupFileRoutes(URLRouter router, IEamPlatform platform) {
	router.post("/api/v1/backups/restore", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () {
			auto data = req.bodyReader.readAll(maxBackupUploadBytes);
			if (data.length == 0) throw new ValidationException("file", "No backup file uploaded (send it as request body)");
			sendJson(res, serializeToJson(platform.restoreUpload(currentTenant(), data, flag(req.query.get("check", "false")),
				req.query.get("keep", "true") != "false", currentSubject())));
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
}
