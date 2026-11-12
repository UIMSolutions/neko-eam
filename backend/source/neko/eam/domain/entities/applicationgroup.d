/// Application group - hierarchical clustering of applications (domain / application landscape),
/// linked to an IT capability. Product totals are rolled up from the applications of the subtree.
module neko.eam.domain.entities.applicationgroup;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class ApplicationGroup {
	mixin ArchitectureElementFields;

	@References("BusinessCapabilities") string capabilityId; /// Capability: IT Capability
	string levelId; /// Level ID
	ObjectState objectState = ObjectState.Active; /// Object State
	@References("ApplicationGroups") string parentGroupId; /// Parent Application Group
	string stakeholder; /// Stakeholder
	int totalUsedProducts; /// Insgesamt genutzte Produkte
	int totalAssignedProducts; /// Insgesamt zugewiesene Produkte

	void validate() const {
		validateAnnotatedFields(this);
		if (parentGroupId.length && parentGroupId == id)
			throw new ValidationException("parentGroupId", "An application group cannot be its own parent");
	}
}
