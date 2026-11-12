/// Strategic guideline - binding principle of the IT strategy that steers the IT landscape planning
/// (e.g. "Cloud first", "Standard software before custom development").
module neko.eam.domain.entities.strategicguideline;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class StrategicGuideline {
	mixin ArchitectureElementFields;

	string shortName;                 /// Short Name
	GuidelineCategory category = GuidelineCategory.Architecture; /// Category
	PlanningPriority priority = PlanningPriority.Medium; /// Priority
	ObjectState status = ObjectState.Draft; /// Status
	string rationale;                 /// Rationale
	string implications;              /// Implications
	string guidelineOwner;            /// Guideline Owner
	@References("Organizations") string ownerOrganizationId; /// Responsible Organization
	@DateField string validFrom;      /// Valid From
	@DateField string validUntil;     /// Valid Until
	@References("StrategicGuidelines") string parentId; /// Parent Guideline
	@References("BusinessCapabilities") string[] capabilityIds; /// Business Capabilities
	/// "Strategic Guideline": full path in the guideline hierarchy (derived at read time).
	string hierarchyPath;

	void validate() const {
		validateAnnotatedFields(this);
		if (parentId.length && parentId == id)
			throw new ValidationException("parentId", "A strategic guideline cannot be its own parent");
		checkDateOrder("validFrom", validFrom, "validUntil", validUntil);
		if (status == ObjectState.Active && guidelineOwner.length == 0)
			throw new ValidationException("guidelineOwner", "An active strategic guideline needs a guideline owner");
		if (status == ObjectState.Active && rationale.length == 0)
			throw new ValidationException("rationale", "An active strategic guideline needs a rationale");
	}
}

unittest {
	auto g = new StrategicGuideline;
	g.name = "Cloud first";
	g.status = ObjectState.Active;
	bool failed;
	try g.validate(); catch (ValidationException e) failed = e.field == "guidelineOwner";
	assert(failed);
	g.guidelineOwner = "CIO";
	g.rationale = "Scalability and time to market";
	g.validate();
	g.validFrom = "2026-01-01"; g.validUntil = "2025-12-31";
	failed = false;
	try g.validate(); catch (ValidationException e) failed = e.field == "validUntil";
	assert(failed);
}
