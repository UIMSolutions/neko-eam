/// Credential - the password of a repository user for the local sign-in (`authMode=local`).
///
/// Kept apart from the `User` element on purpose: it is never exposed through OData, REST, the workbook
/// export or the reports. Only the salted hash is stored (format of the `IPasswordHasher`).
module neko.eam.domain.entities.credential;

import std.algorithm : canFind;
import std.string : toLower;
import neko.eam.domain.exceptions;

final class Credential {
	string userId;       /// id of the `User` (stable across renames of the user name)
	string passwordHash; /// encoded salted hash, e.g. "pbkdf2-sha256$120000$<salt>$<hash>"
	string changedAt;    /// ISO timestamp of the last change
	string changedBy;    /// who set the password (the user, or an administrator)
	/// Set by an administrator: the user must choose a new password after the next sign-in.
	bool mustChange;
}

/// Password rules of the local sign-in.
struct PasswordPolicy {
	enum size_t minLength = 10;
	enum size_t maxLength = 256;

	/// Throws ValidationException (field "password") if `password` is not acceptable for `userName`.
	static void check(string password, string userName) {
		if (password.length < minLength)
			throw new ValidationException("password", "The password must have at least 10 characters");
		if (password.length > maxLength)
			throw new ValidationException("password", "The password must not have more than 256 characters");
		if (userName.length && password.toLower.canFind(userName.toLower))
			throw new ValidationException("password", "The password must not contain the user name");
		bool letter, other;
		foreach (dchar c; password) {
			if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) letter = true;
			else other = true;
		}
		if (!letter || !other)
			throw new ValidationException("password", "The password must contain letters and digits or special characters");
	}
}

unittest {
	bool rejected(string pw, string user = "anna") {
		try PasswordPolicy.check(pw, user); catch (ValidationException e) return e.field == "password";
		return false;
	}
	assert(rejected("short1"));
	assert(rejected("onlyletterslong"));
	assert(rejected("1234567890123"));
	assert(rejected("xxANNA-2026xx"));
	assert(!rejected("correct horse 7"));
}
