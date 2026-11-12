/// Mapping of business / technical exceptions to HTTP status codes.
module neko.eam.presentation.http.errors;

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
	if (cast(AuthorizationException) e) return ErrorInfo(HTTPStatus.forbidden, "Forbidden");
	if (cast(AccessDeniedException) e) return ErrorInfo(HTTPStatus.forbidden, "Forbidden");
	return ErrorInfo(HTTPStatus.internalServerError, "InternalError");
}
