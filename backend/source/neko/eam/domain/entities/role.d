/// Role - bundles permissions; users get their rights only through roles.
module neko.eam.domain.entities.role;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class Role {
	mixin ArchitectureElementFields;

	string roleKey;                   /// Role Key
	ObjectState status = ObjectState.Active; /// Status (only active roles grant rights)
	@References("Permissions") string[] permissionIds; /// Permissions
	int totalUsers;                   /// Total Users (derived)

	void validate() const {
		validateAnnotatedFields(this);
	}
}
