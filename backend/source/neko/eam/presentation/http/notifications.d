/// HTTP endpoints of the notifications of the signed-in user (Fiori shell bar):
///
///   GET  /api/v1/notifications           {unread, items}: alerts first, then activities (newest first)
///   POST /api/v1/notifications/read      {ids: [...]} or {all: true}  -> updated list
///   POST /api/v1/notifications/dismiss   {ids: [...]} or {all: true}  -> updated list
module neko.eam.presentation.http.notifications;

import vibe.data.json;
import vibe.http.router : URLRouter;
import vibe.http.server;
import neko.eam.domain.exceptions : ValidationException;
import neko.eam.ports.usecases;
import neko.eam.presentation.http.access;
import neko.eam.presentation.http.errors;

/// Most ids accepted in one request.
enum maxIdsPerRequest = 1000;

void registerNotificationRoutes(URLRouter router, IEamUseCases uc) {
	router.get("/api/v1/notifications", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () {
			res.headers["Cache-Control"] = "no-store";
			sendJson(res, serializeToJson(uc.notifications.forUser(currentSubject())));
		});
	});
	router.post("/api/v1/notifications/read", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () {
			auto r = selection(req);
			sendJson(res, serializeToJson(uc.notifications.markRead(currentSubject(), r.ids, r.all)));
		});
	});
	router.post("/api/v1/notifications/dismiss", (HTTPServerRequest req, HTTPServerResponse res) {
		respond(res, () {
			auto r = selection(req);
			sendJson(res, serializeToJson(uc.notifications.dismiss(currentSubject(), r.ids, r.all)));
		});
	});
}

private struct Selection { string[] ids; bool all; }

private Selection selection(HTTPServerRequest req) {
	Json body;
	try body = req.json; catch (Exception) {}
	if (body.type != Json.Type.object) throw new ValidationException("ids", "JSON body {ids: [...]} or {all: true} expected");
	Selection s;
	s.all = body["all"].opt!bool(false);
	auto ids = body["ids"];
	if (ids.type == Json.Type.array) {
		if (ids.length > maxIdsPerRequest) throw new ValidationException("ids", "Too many ids in one request");
		foreach (id; ids) if (id.type == Json.Type.string) s.ids ~= id.get!string;
	}
	if (!s.all && !s.ids.length) throw new ValidationException("ids", "No notifications given");
	return s;
}
