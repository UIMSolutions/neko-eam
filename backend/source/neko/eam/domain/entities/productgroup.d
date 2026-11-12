/// Product group - hierarchical classification of the product catalogue, linked to an IT capability.
module neko.eam.domain.entities.productgroup;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class ProductGroup {
	mixin ArchitectureElementFields;

	@References("BusinessCapabilities") string capabilityId; /// Capability: IT Capability
	string levelId; /// Level ID
	ObjectState objectState = ObjectState.Active; /// Object State
	@References("ProductGroups") string parentGroupId; /// Parent Product Group

	void validate() const {
		validateAnnotatedFields(this);
		if (parentGroupId.length && parentGroupId == id)
			throw new ValidationException("parentGroupId", "A product group cannot be its own parent");
	}
}
