/// User - person (or technical account) known to the EAM; matched to the signed-in principal by
/// user name or e-mail. Rights come from the user's active roles.
module neko.eam.domain.entities.user;

import std.algorithm : canFind;
import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class User {
	mixin ArchitectureElementFields;

	@Required string userName;        /// User Name (login, unique)
	string email;                     /// E-Mail
	bool active = true;               /// Active
	@DateField string validUntil;     /// Valid Until
	@References("Organizations") string organizationId; /// Organization
	@References("Roles") string[] roleIds; /// Roles
	string effectiveRights;           /// Effective Rights (derived)

	/// Active and not expired at `today` (ISO date).
	bool isEnabled(string today) const pure @safe {
		return active && (validUntil.length == 0 || validUntil >= today);
	}

	void validate() const {
		validateAnnotatedFields(this);
		if (userName.canFind(' '))
			throw new ValidationException("userName", "The user name must not contain blanks");
		if (email.length && !email.canFind('@'))
			throw new ValidationException("email", "'" ~ email ~ "' is not an e-mail address");
	}
}

unittest {
	auto u = new User;
	u.name = "Anna Architect";
	bool failed;
	try u.validate(); catch (ValidationException e) failed = e.field == "userName";
	assert(failed);
	u.userName = "anna";
	u.validate();
	assert(u.isEnabled("2026-11-12"));
	u.validUntil = "2026-01-01";
	assert(!u.isEnabled("2026-11-12"));
}
