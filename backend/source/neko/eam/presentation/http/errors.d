/// Mapping of business / technical exceptions to HTTP status codes.
module neko.eam.presentation.http.errors;

import vibe.data.json : Json;
import vibe.http.server : HTTPServerResponse;
import vibe.http.common : HTTPStatusException;
import vibe.http.status : HTTPStatus;
import neko.eam.domain.exceptions;
import neko.eam.infrastructure.security : AuthenticationException, AuthorizationException;
import neko.eam.presentation.odata.query : ODataQueryException;

struct ErrorInfo {
	HTTPStatus status;
	string code;
}

ErrorInfo classify(Exception e) {
	if (cast(ValidationException) e) return ErrorInfo(HTTPStatus.badRequest, "ValidationError");
	if (cast(ODataQueryException) e) return ErrorInfo(HTTPStatus.badRequest, "InvalidQuery");
	if (cast(EntityNotFoundException) e) return ErrorInfo(HTTPStatus.notFound, "NotFound");
	if (cast(ConflictException) e) return ErrorInfo(HTTPStatus.conflict, "Conflict");
	if (cast(ReferentialIntegrityException) e) return ErrorInfo(HTTPStatus.conflict, "ReferentialIntegrity");
	if (cast(AuthenticationException) e) return ErrorInfo(HTTPStatus.unauthorized, "Unauthorized");
	if (cast(InvalidCredentialsException) e) return ErrorInfo(HTTPStatus.unauthorized, "InvalidCredentials");
	if (cast(AuthorizationException) e) return ErrorInfo(HTTPStatus.forbidden, "Forbidden");
	if (cast(AccessDeniedException) e) return ErrorInfo(HTTPStatus.forbidden, "Forbidden");
	return ErrorInfo(HTTPStatus.internalServerError, "InternalError");
}

/// Writes `body` as JSON (UTF-8).
void sendJson(HTTPServerResponse res, Json body) {
	res.writeBody(body.toString, "application/json; charset=utf-8");
}

/// Writes an OData style error body `{"error": {code, message[, target]}}` with `status`.
void sendError(HTTPServerResponse res, HTTPStatus status, string code, string message, string target = null) {
	auto err = Json(["code": Json(code), "message": Json(message)]);
	if (target.length) err["target"] = target;
	res.statusCode = status;
	sendJson(res, Json(["error": err]));
}

/// Runs a route body and answers business errors as OData style JSON; internal errors are logged and
/// reported without details. HTTPStatusExceptions pass through to the server's error page handler.
void respond(HTTPServerResponse res, scope void delegate() fn) {
	try fn();
	catch (HTTPStatusException e) throw e;
	catch (Exception e) {
		auto info = classify(e);
		if (info.status >= 500) {
			import neko.eam.infrastructure.logging : logError;
			logError("%s", e.toString());
		}
		auto v = cast(ValidationException) e;
		sendError(res, info.status, info.code, info.status >= 500 ? "Internal server error" : e.msg, v is null ? null : v.field);
	}
}
