/// Service capability - ability of IT to deliver a service (IT capability map of the landscape planning),
/// assessed by its current and target maturity. The maturity gap is derived.
module neko.eam.domain.entities.servicecapability;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class ServiceCapability {
	mixin ArchitectureElementFields;

	string shortName;                 /// Short Name
	string levelId;                   /// Level ID
	LifecycleStatus status = LifecycleStatus.Active; /// Status
	Criticality missionCriticality = Criticality.Medium; /// Mission Criticality
	int currentMaturity = 1;          /// Current Maturity (1-5)
	int targetMaturity = 3;           /// Target Maturity (1-5)
	string stakeholder;               /// Stakeholder
	@References("Organizations") string ownerOrganizationId; /// Responsible Organization
	@References("ServiceCapabilities") string parentId; /// Parent Service Capability
	@References("BusinessCapabilities") string businessCapabilityId; /// Supported Business Capability
	@References("ServiceProductGroups") string[] serviceProductGroupIds; /// Service Catalogues
	@References("Applications") string[] applicationIds; /// Supporting Applications
	/// "Service Capability": full path in the capability hierarchy (derived at read time).
	string hierarchyPath;

	/// Maturity Gap: how many levels are missing to reach the target maturity (derived).
	int maturityGap;

	void derive() {
		maturityGap = targetMaturity > currentMaturity ? targetMaturity - currentMaturity : 0;
	}

	void validate() const {
		validateAnnotatedFields(this);
		if (parentId.length && parentId == id)
			throw new ValidationException("parentId", "A service capability cannot be its own parent");
		checkRange("currentMaturity", currentMaturity, 1, 5);
		checkRange("targetMaturity", targetMaturity, 1, 5);
	}
}

unittest {
	auto c = new ServiceCapability;
	c.name = "Identity & Access Management";
	c.currentMaturity = 2; c.targetMaturity = 4;
	c.derive();
	c.validate();
	assert(c.maturityGap == 2);
	c.targetMaturity = 6;
	bool failed;
	try c.validate(); catch (ValidationException e) failed = e.field == "targetMaturity";
	assert(failed);
}
