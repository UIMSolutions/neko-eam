/// Business capability - what the business does, organised as a hierarchy (capability map).
module neko.eam.domain.entities.businesscapability;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class BusinessCapability {
	mixin ArchitectureElementFields;

	int level = 1;                    /// Level ID Number: 1 = top level capability, up to 5
	int strategicImportance = 3;      /// 1 .. 5
	@References("BusinessCapabilities") string parentId; /// Parent Business Capability
	@References("Organizations") string ownerOrganizationId;
	string levelId;                   /// Level ID (e.g. "BC-1.2")
	Criticality missionCriticality = Criticality.Medium; /// Mission Criticality
	string stakeholder;               /// Stakeholder
	/// "Business Capability": full path in the capability map (derived at read time).
	string hierarchyPath;

	void validate() const {
		validateAnnotatedFields(this);
		checkRange("level", level, 1, 5);
		checkRange("strategicImportance", strategicImportance, 1, 5);
		if (parentId.length && parentId == id)
			throw new ValidationException("parentId", "A capability cannot be its own parent");
		if (level == 1 && parentId.length)
			throw new ValidationException("parentId", "A level 1 capability must not have a parent");
	}
}
