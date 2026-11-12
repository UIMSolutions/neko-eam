/// HTTP endpoints for the CSV / XLSX import and export of entity sets.
///
///   GET  /api/v1/transfer/{Set}?format=csv|xlsx[&headers=names][&sep=;]   one set as file
///   GET  /api/v1/transfer?format=xlsx[&headers=names]                       all sets, one sheet per set
///   POST /api/v1/transfer/{Set}[?dryRun=true]                               import one set (CSV or XLSX)
///   POST /api/v1/transfer[?dryRun=true]                                     import a workbook (all sheets)
///
/// Uploads are the raw file as request body or a multipart/form-data file field; the format is detected
/// from the content. Imports need the write scope (route guard) and are stamped with the user name.
module neko.eam.presentation.http.transfer;

import std.datetime : Clock, Date;
import std.file : read;
import vibe.data.json;
import vibe.http.router : URLRouter;
import vibe.http.server;
import vibe.stream.operations : readAll;
import neko.eam.domain.exceptions : ValidationException;
import neko.eam.ports.usecases;
import neko.eam.ports.services : ITableCodec;
import neko.eam.infrastructure.formats;
import neko.eam.infrastructure.security;
import neko.eam.presentation.http.errors;
import neko.eam.presentation.http.jsoncodec;
import neko.eam.presentation.http.access;

/// Largest accepted upload.
enum maxUploadBytes = 32 * 1024 * 1024;

void registerTransferRoutes(URLRouter router, IEamUseCases uc, Authenticator auth) {
	router.get("/api/v1/transfer", (HTTPServerRequest req, HTTPServerResponse res) {
		handle(res, () {
			auto codec = codecFor(req.query.get("format", "xlsx"), separator(req));
			if (codec.format != "xlsx")
				throw new ValidationException("format", "Exporting all entity sets needs format=xlsx (one sheet per set)");
			send(res, codec, callerUseCases(uc).transfer.exportAll(technical(req)), "eam-repository");
		});
	});
	router.get("/api/v1/transfer/:set", (HTTPServerRequest req, HTTPServerResponse res) {
		handle(res, () {
			auto set = req.params["set"];
			auto codec = codecFor(req.query.get("format", "csv"), separator(req));
			send(res, codec, [callerUseCases(uc).transfer.exportSet(set, technical(req))], "eam-" ~ set);
		});
	});
	router.post("/api/v1/transfer", (HTTPServerRequest req, HTTPServerResponse res) {
		handle(res, () {
			auto data = upload(req);
			auto sheets = codecForContent(data).decode(data);
			auto results = callerUseCases(uc).transfer.importAll(sheets, actor(req, auth), dryRun(req));
			res.writeBody(serializeToJsonString(results), "application/json; charset=utf-8");
		});
	});
	router.post("/api/v1/transfer/:set", (HTTPServerRequest req, HTTPServerResponse res) {
		handle(res, () {
			auto set = req.params["set"];
			auto data = upload(req);
			auto sheets = codecForContent(data).decode(data);
			auto result = callerUseCases(uc).transfer.importSet(set, pickSheet(sheets, set), actor(req, auth), dryRun(req));
			res.writeBody(serializeToJsonString(result), "application/json; charset=utf-8");
		});
	});
}

/// The sheet named like the set (name or label), otherwise the first sheet.
TableDto pickSheet(TableDto[] sheets, string setName) {
	import neko.eam.application.usecases.transferelements : resolveSet;
	auto wanted = resolveSet(setName);
	foreach (s; sheets) if (s.name.length && resolveSet(s.name) == wanted) return s;
	return sheets[0];
}

private:

void send(HTTPServerResponse res, ITableCodec codec, TableDto[] sheets, string baseName) {
	auto bytes = codec.encode(sheets);
	auto stamp = (cast(Date) Clock.currTime()).toISOExtString();
	res.headers["Content-Disposition"] = `attachment; filename="` ~ baseName ~ "-" ~ stamp ~ "." ~ codec.format ~ `"`;
	res.headers["Cache-Control"] = "no-store";
	res.writeBody(bytes, codec.mimeType);
}

const(ubyte)[] upload(HTTPServerRequest req) {
	const(ubyte)[] data;
	if (req.contentType == "multipart/form-data") {
		foreach (name, file; req.files.byKeyValue) { data = cast(const(ubyte)[]) read(file.tempPath.toString); break; }
	} else
		data = req.bodyReader.readAll(maxUploadBytes);
	if (data.length == 0) throw new ValidationException("file", "No file uploaded (send the CSV / XLSX file as request body)");
	return data;
}

string actor(HTTPServerRequest req, Authenticator auth) {
	return currentSubject().userName;
}

bool technical(HTTPServerRequest req) { return req.query.get("headers", "labels") == "names"; }

bool dryRun(HTTPServerRequest req) {
	auto v = req.query.get("dryRun", "false");
	return v == "true" || v == "1";
}

char separator(HTTPServerRequest req) {
	switch (req.query.get("sep", ",")) {
		case ";", "semicolon": return ';';
		case "\t", "tab": return '\t';
		default: return ',';
	}
}

/// Business errors as OData style JSON (`{"error": {code, message, target}}`).
void handle(HTTPServerResponse res, scope void delegate() fn) {
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
