/// Shared plumbing of the vibe.d REST interfaces: one error format for all of them, `201 Created` for
/// creating methods and the query flags the Fiori app sends.
module neko.eam.presentation.rest.support;

import vibe.http.common : HTTPStatusException;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import vibe.http.status : HTTPStatus;
import vibe.web.rest : RestErrorInformation, RestInterfaceSettings;
import neko.eam.domain.exceptions : ValidationException;
import neko.eam.presentation.http.errors : classify, sendError;

/// Settings every REST interface of the backend is registered with.
///
/// Errors use the OData style body `{"error": {code, message[, target]}}` of the OData service and the raw
/// routes (instead of vibe.d's `{"statusMessage"}`), so clients parse one format: business exceptions are
/// mapped by `classify` (validation -> 400 with `target`, not found -> 404, conflict -> 409, ...), internal
/// errors are logged and answered without details.
RestInterfaceSettings restSettings() {
	auto settings = new RestInterfaceSettings;
	settings.errorHandler = (HTTPServerRequest req, HTTPServerResponse res, RestErrorInformation info) @safe {
		writeRestError(res, info.exception, info.statusCode);
	};
	return settings;
}

/// Writes `e` (or `fallback` without exception) as OData style error.
void writeRestError(HTTPServerResponse res, Exception e, HTTPStatus fallback) @trusted {
	if (e is null) return sendError(res, fallback, codeOf(fallback), httpReason(fallback));
	if (auto he = cast(HTTPStatusException) e) {
		auto status = cast(HTTPStatus) he.status;
		return sendError(res, status, codeOf(status), he.msg);
	}
	auto info = classify(e);
	if (info.status >= 500) {
		import neko.eam.infrastructure.logging : logError;
		logError("%s", e.toString());
		return sendError(res, info.status, info.code, "Internal server error");
	}
	auto v = cast(ValidationException) e;
	sendError(res, info.status, info.code, e.msg, v is null ? null : v.field);
}

/// Route handler (register before the REST interfaces): answers a JSON request body that cannot be parsed
/// with 400. vibe.d parses the body before the REST error handler is in place, so a malformed body would
/// otherwise end as 500. Other content types (file uploads) are not parsed and pass through.
void rejectMalformedJson(HTTPServerRequest req, HTTPServerResponse res) @trusted {
	try cast(void) req.json;
	catch (Exception) sendError(res, HTTPStatus.badRequest, "ValidationError", "The request body is not valid JSON");
}

/// `@after!(created!T)()`: answers a successful creating method with `201 Created`.
T created(T)(T result, HTTPServerRequest req, HTTPServerResponse res) @safe {
	res.statusCode = HTTPStatus.created;
	return result;
}

/// Query flag as sent by the Fiori app (`true` / `1`; anything else is false).
bool flag(string value) @safe pure nothrow {
	return value == "true" || value == "1";
}

/// Error code for an HTTP status raised by vibe.d itself (malformed body, missing parameter, ...).
private string codeOf(HTTPStatus status) @safe pure nothrow {
	switch (status) {
		case HTTPStatus.badRequest: return "BadRequest";
		case HTTPStatus.unauthorized: return "Unauthorized";
		case HTTPStatus.forbidden: return "Forbidden";
		case HTTPStatus.notFound: return "NotFound";
		case HTTPStatus.conflict: return "Conflict";
		default: return status >= 500 ? "InternalError" : "HttpError";
	}
}

private string httpReason(HTTPStatus status) @safe {
	import vibe.http.status : httpStatusText;
	return httpStatusText(status);
}

unittest {
	assert(flag("true") && flag("1") && !flag("false") && !flag("") && !flag("yes"));
	assert(codeOf(HTTPStatus.badRequest) == "BadRequest" && codeOf(HTTPStatus.serviceUnavailable) == "InternalError");
	assert(codeOf(HTTPStatus.gone) == "HttpError");
}
