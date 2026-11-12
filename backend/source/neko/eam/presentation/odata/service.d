/// OData v4 endpoint: service document, $metadata, entity set and entity CRUD.
module neko.eam.presentation.odata.service;

import std.algorithm : startsWith, endsWith;
import std.conv : to;
import std.string : indexOf;
import vibe.data.json;
import vibe.http.router : URLRouter;
import vibe.http.server;
import vibe.http.status : HTTPStatus;
import vibe.textfilter.urlencode : urlDecode;
import neko.eam.ports.usecases;
import neko.eam.domain.exceptions : ValidationException;
import neko.eam.infrastructure.logging;
import neko.eam.infrastructure.security;
import neko.eam.presentation.http.errors;
import neko.eam.presentation.http.access;
import neko.eam.presentation.http.jsoncodec;
import neko.eam.presentation.odata.metadata;
import neko.eam.presentation.odata.query;

class ODataService {
	private {
		IEamUseCases _uc;
		Authenticator _auth;
		string _base;
		string _metadata;
	}

	this(IEamUseCases uc, Authenticator auth, string basePath) {
		_uc = uc;
		_auth = auth;
		_base = basePath.endsWith("/") ? basePath[0 .. $ - 1] : basePath;
		_metadata = buildMetadata();
	}

	void register(URLRouter router) {
		router.any(_base, &handle);
		router.any(_base ~ "/*", &handle);
	}

	void handle(HTTPServerRequest req, HTTPServerResponse res) {
		res.headers["OData-Version"] = "4.0";
		try {
			auto subject = establishSubject(req, _auth);
			dispatch(req, res, resourcePath(req), subject.userName);
		} catch (Exception e) {
			writeError(res, e);
		}
	}

	/// Part of the URL after the service root, URL-decoded, without query string.
	private string resourcePath(HTTPServerRequest req) {
		string uri = req.requestURI;
		auto q = uri.indexOf('?');
		if (q >= 0) uri = uri[0 .. q];
		uri = urlDecode(uri);
		auto p = uri.length > _base.length ? uri[_base.length .. $] : "";
		while (p.startsWith("/")) p = p[1 .. $];
		return p;
	}

	private void dispatch(HTTPServerRequest req, HTTPServerResponse res, string path, string actor) {
		if (path == "") {
			if (req.method == HTTPMethod.HEAD) return res.writeVoidBody(); // UI5 CSRF token fetch
			requireMethod(req, HTTPMethod.GET);
			return writeJson(res, HTTPStatus.ok, buildServiceDocument());
		}
		if (path == "$metadata") {
			requireMethod(req, HTTPMethod.GET);
			return res.writeBody(_metadata, "application/xml");
		}
		if (path == "$batch")
			throw new HTTPStatusException(HTTPStatus.notImplemented, "$batch is not supported, use groupId $direct");

		string set = path, key, suffix;
		auto paren = path.indexOf('(');
		auto slash = path.indexOf('/');
		if (paren > 0 && (slash < 0 || paren < slash)) {
			set = path[0 .. paren];
			auto close = path.indexOf(')', paren);
			if (close < 0) throw new ODataQueryException("Malformed key in " ~ path);
			key = parseKey(path[paren + 1 .. close]);
			suffix = path[close + 1 .. $];
		} else if (slash > 0) {
			set = path[0 .. slash];
			suffix = path[slash .. $];
		}
		static foreach (S; EamDtoSets) {
			if (set == S.setName) return handleSet!S(req, res, key, suffix, actor);
		}
		throw new HTTPStatusException(HTTPStatus.notFound, "Unknown resource '" ~ set ~ "'");
	}

	private void handleSet(alias S)(HTTPServerRequest req, HTTPServerResponse res, string key, string suffix, string actor) {
		auto uc = manage!S(callerUseCases(_uc));
		enum ctx = "$metadata#" ~ S.setName;
		if (key.length == 0) {
			if (suffix == "/$count") {
				requireMethod(req, HTTPMethod.GET);
				auto q = QueryOptions.parse(queryParams(req));
				q.top = -1; q.skip = 0;
				return res.writeBody(applyQuery(collection!S(uc), q).totalCount.to!string, "text/plain");
			}
			if (suffix.length) throw new HTTPStatusException(HTTPStatus.notFound, "Unsupported path " ~ suffix);
			switch (req.method) {
				case HTTPMethod.GET:
					auto q = QueryOptions.parse(queryParams(req));
					auto r = applyQuery(collection!S(uc), q);
					auto body = Json.emptyObject;
					body["@odata.context"] = ctx;
					if (q.count) body["@odata.count"] = r.totalCount;
					body["value"] = Json(r.items);
					return writeJson(res, HTTPStatus.ok, body);
				case HTTPMethod.POST:
					auto created = uc.create(dtoFromJson!(S.Dto)(req.json), actor);
					res.headers["Location"] = _base ~ "/" ~ S.setName ~ "('" ~ created.id ~ "')";
					return writeEntity(res, HTTPStatus.created, ctx, created);
				default:
					throw new HTTPStatusException(HTTPStatus.methodNotAllowed);
			}
		}
		if (suffix.length) throw new HTTPStatusException(HTTPStatus.notFound, "Navigation/property paths are not supported");
		switch (req.method) {
			case HTTPMethod.GET:
				auto q = QueryOptions.parse(queryParams(req));
				auto j = dtoToJson(uc.get(key));
				if (q.select.length) j = selectFields(j, q.select);
				j["@odata.context"] = ctx ~ "/$entity";
				return writeJson(res, HTTPStatus.ok, j);
			case HTTPMethod.PATCH:
				auto merged = dtoFromJson!(S.Dto)(req.json, uc.get(key));
				return writeEntity(res, HTTPStatus.ok, ctx, uc.update(key, merged, actor));
			case HTTPMethod.PUT:
				uc.get(key); // 404 if missing
				S.Dto fresh;
				return writeEntity(res, HTTPStatus.ok, ctx, uc.update(key, dtoFromJson!(S.Dto)(req.json, fresh), actor));
			case HTTPMethod.DELETE:
				uc.remove(key);
				res.statusCode = HTTPStatus.noContent;
				return res.writeVoidBody();
			default:
				throw new HTTPStatusException(HTTPStatus.methodNotAllowed);
		}
	}

	private static Json[] collection(alias S, U)(U uc) {
		Json[] rows;
		foreach (dto; uc.list) rows ~= dtoToJson(dto);
		return rows;
	}

	private static void writeEntity(T)(HTTPServerResponse res, HTTPStatus status, string ctx, T dto) {
		auto j = dtoToJson(dto);
		j["@odata.context"] = ctx ~ "/$entity";
		writeJson(res, status, j);
	}

	private static void writeJson(HTTPServerResponse res, HTTPStatus status, Json j) {
		res.statusCode = status;
		res.writeBody(j.toString(), "application/json;odata.metadata=minimal");
	}

	private static void writeError(HTTPServerResponse res, Exception e) {
		ErrorInfo info;
		if (auto he = cast(HTTPStatusException) e) info = ErrorInfo(cast(HTTPStatus) he.status, "HttpError");
		else info = classify(e);
		if (info.status >= 500) logError("OData request failed: %s", e.toString());
		auto msg = info.status >= 500 ? "Internal server error" : e.msg;
		if (auto he = cast(HTTPStatusException) e) msg = he.msg;
		auto err = Json(["code": Json(info.code), "message": Json(msg)]);
		// OData v4 error "target": the property that failed validation (used by Fiori to highlight the field)
		if (auto ve = cast(ValidationException) e) if (ve.field.length) err["target"] = ve.field;
		writeJson(res, info.status, Json(["error": err]));
	}

	private static string[string] queryParams(HTTPServerRequest req) {
		string[string] r;
		foreach (k, v; req.query.byKeyValue) r[k] = v;
		return r;
	}

	private static void requireMethod(HTTPServerRequest req, HTTPMethod m) {
		if (req.method != m) throw new HTTPStatusException(HTTPStatus.methodNotAllowed);
	}
}

/// Accepts `'id'`, `id='id'` and unquoted keys; doubled quotes are unescaped.
string parseKey(string raw) {
	import std.array : replace;
	auto k = raw;
	if (k.startsWith("id=")) k = k[3 .. $];
	if (k.length >= 2 && k[0] == '\'' && k[$ - 1] == '\'') k = k[1 .. $ - 1].replace("''", "'");
	if (k.length == 0) throw new ODataQueryException("Empty key");
	return k;
}

unittest {
	assert(parseKey("'app-1'") == "app-1");
	assert(parseKey("id='o''brien'") == "o'brien");
	assert(parseKey("42") == "42");
}
