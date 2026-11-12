/// HTTP endpoints of the running comments (journal) of any element:
///
///   GET    /api/v1/comments/{set}/{id}       comments of an element, newest first
///   POST   /api/v1/comments/{set}/{id}       add  {text}
///   DELETE /api/v1/comments/{commentId}      author, or delete permission on the element's set
module neko.eam.presentation.http.comments;

import vibe.data.json;
import vibe.http.router : URLRouter;
import vibe.http.server;
import neko.eam.domain.exceptions : ValidationException;
import neko.eam.ports.usecases;
import neko.eam.presentation.http.access;
import neko.eam.presentation.http.errors;

void registerCommentRoutes(URLRouter router, IEamUseCases uc) {
	router.get("/api/v1/comments/:set/:id", (HTTPServerRequest req, HTTPServerResponse res) {
		run(res, () => json(res, serializeToJson(callerUseCases(uc).comments.list(req.params["set"], req.params["id"],
			currentSubject().userName))));
	});
	router.post("/api/v1/comments/:set/:id", (HTTPServerRequest req, HTTPServerResponse res) {
		run(res, () {
			string text;
			try text = req.json["text"].opt!string(""); catch (Exception) {}
			auto c = callerUseCases(uc).comments.add(req.params["set"], req.params["id"], text, currentSubject().userName);
			c.deletable = true;
			res.statusCode = HTTPStatus.created;
			json(res, serializeToJson(c));
		});
	});
	router.delete_("/api/v1/comments/:commentId", (HTTPServerRequest req, HTTPServerResponse res) {
		run(res, () { callerUseCases(uc).comments.remove(req.params["commentId"], currentSubject().userName); res.writeVoidBody(); });
	});
}

private void json(HTTPServerResponse res, Json body) {
	res.writeBody(body.toString, "application/json; charset=utf-8");
}

private void run(HTTPServerResponse res, scope void delegate() fn) {
	try fn();
	catch (HTTPStatusException e) throw e;
	catch (Exception e) {
		auto info = classify(e);
		auto err = Json(["code": Json(info.code), "message": Json(info.status >= 500 ? "Internal server error" : e.msg)]);
		if (auto v = cast(ValidationException) e) err["target"] = v.field;
		res.statusCode = info.status;
		res.writeBody(Json(["error": err]).toString, "application/json; charset=utf-8");
	}
}
