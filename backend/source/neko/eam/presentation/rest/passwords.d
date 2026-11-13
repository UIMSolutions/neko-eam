/// REST interface of the passwords of the local sign-in (`authMode=local`):
///
///   POST   /api/v1/me/password                {currentPassword, newPassword} - change the own password
///   GET    /api/v1/users/{userName}/password  {hasPassword, localSignIn}     (read permission on Users)
///   PUT    /api/v1/users/{userName}/password  {password, mustChange?}       (update permission on Users)
///   DELETE /api/v1/users/{userName}/password  sign-in no longer possible    (update permission on Users)
///
/// A changed or removed password ends the other sessions of that user. Sign-in and sign-out set the session
/// cookie and stay raw routes in `presentation.http.login`.
module neko.eam.presentation.rest.passwords;

import vibe.http.common : HTTPMethod;
import vibe.web.rest;
import neko.eam.domain.exceptions : ValidationException;
import neko.eam.infrastructure.logging : logInfo;
import neko.eam.infrastructure.security : Authenticator;
import neko.eam.ports.usecases;
import neko.eam.presentation.http.access;

/// Password state of a repository user.
struct PasswordStateDto {
	bool hasPassword;
	/// The server uses the local sign-in (otherwise passwords are not used).
	bool localSignIn;
}

@path("/api/v1")
interface IPasswordsApi {
@safe:
	@method(HTTPMethod.POST) @path("/me/password")
	void changeOwnPassword(string currentPassword = "", string newPassword = "");

	@method(HTTPMethod.GET) @path("/users/:userName/password")
	PasswordStateDto getPasswordState(string _userName);

	@method(HTTPMethod.PUT) @path("/users/:userName/password")
	void setPassword(string _userName, string password = "", bool mustChange = true);

	@method(HTTPMethod.DELETE) @path("/users/:userName/password")
	void removePassword(string _userName);
}

class PasswordsApi : IPasswordsApi {
	private {
		IEamUseCases _uc;
		Authenticator _auth;
	}

	this(IEamUseCases uc, Authenticator auth) { _uc = uc; _auth = auth; }

	void changeOwnPassword(string currentPassword = "", string newPassword = "") @trusted {
		auto session = currentSession();
		if (!_auth.local || session is null)
			throw new ValidationException("authMode", "Passwords are only used with the local sign-in");
		if (session.administrator)
			throw new ValidationException("password", "The password of the built-in administrator is set in the server configuration (EAM_ADMIN_PASSWORD)");
		_uc.access.changePassword(session.userName, currentPassword, newPassword);
		session.mustChangePassword = false;
		logInfo("Password of '%s' (tenant %s) changed by the user", session.userName, session.tenant);
		// other browsers of the user have to sign in with the new password
		loginSessions.destroyForUser(session.tenant, session.userName, session.id);
	}

	PasswordStateDto getPasswordState(string _userName) @trusted {
		callerUseCases(_uc).users.count; // read permission on Users
		return PasswordStateDto(_uc.access.hasPassword(_userName), _auth.local);
	}

	void setPassword(string _userName, string password = "", bool mustChange = true) @trusted {
		_uc.access.setPassword(_userName, password, currentSubject(), mustChange);
		auto keep = currentSession();
		loginSessions.destroyForUser(currentTenant(), _userName, keep is null ? null : keep.id);
		logInfo("Password of '%s' (tenant %s) set by '%s'", _userName, currentTenant(), currentSubject().userName);
	}

	void removePassword(string _userName) @trusted {
		_uc.access.removePassword(_userName, currentSubject());
		loginSessions.destroyForUser(currentTenant(), _userName);
		logInfo("Password of '%s' (tenant %s) removed by '%s'", _userName, currentTenant(), currentSubject().userName);
	}
}
