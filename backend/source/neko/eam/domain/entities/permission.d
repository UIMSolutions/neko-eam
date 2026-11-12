/// Permission - grants read / create / update / delete on one entity set (or on all sets).
module neko.eam.domain.entities.permission;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class Permission {
	mixin ArchitectureElementFields;

	EntitySetName entitySet = EntitySetName.All; /// Entity Set
	bool canRead = true;              /// Read
	bool canCreate;                   /// Create
	bool canUpdate;                   /// Update
	bool canDelete;                   /// Delete
	int totalRoles;                   /// Total Roles (derived)

	void validate() const {
		validateAnnotatedFields(this);
		if (!canRead && (canCreate || canUpdate || canDelete))
			throw new ValidationException("canRead", "Create, update and delete require the read permission");
	}
}

unittest {
	auto p = new Permission;
	p.name = "Edit applications";
	p.canRead = false; p.canUpdate = true;
	bool failed;
	try p.validate(); catch (ValidationException e) failed = e.field == "canRead";
	assert(failed);
	p.canRead = true;
	p.validate();
}
