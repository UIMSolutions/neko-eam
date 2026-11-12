/// Architecture principle - enduring, general rule for the architecture (TOGAF style: statement,
/// rationale, implications), derived from the strategic guidelines of the IT strategy.
module neko.eam.domain.entities.architectureprinciple;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class ArchitecturePrinciple {
	mixin ArchitectureElementFields;

	string shortName;                 /// Short Name
	ArchitectureDomain domain = ArchitectureDomain.Application; /// Architecture Domain
	PlanningPriority priority = PlanningPriority.Medium; /// Priority
	SpecificationStatus status = SpecificationStatus.Draft; /// Status
	string specVersion;               /// Version
	string statement;                 /// Statement
	string rationale;                 /// Rationale
	string implications;              /// Implications
	string principleOwner;            /// Principle Owner
	@References("Organizations") string ownerOrganizationId; /// Responsible Organization
	@DateField string validFrom;      /// Valid From
	@DateField string validUntil;     /// Valid Until
	@References("StrategicGuidelines") string[] strategicGuidelineIds; /// Strategic Guidelines

	void validate() const {
		validateAnnotatedFields(this);
		checkDateOrder("validFrom", validFrom, "validUntil", validUntil);
		if (status == SpecificationStatus.Approved) {
			if (principleOwner.length == 0)
				throw new ValidationException("principleOwner", "An approved architecture principle needs a principle owner");
			if (statement.length == 0)
				throw new ValidationException("statement", "An approved architecture principle needs a statement");
			if (rationale.length == 0)
				throw new ValidationException("rationale", "An approved architecture principle needs a rationale");
		}
	}
}

unittest {
	auto p = new ArchitecturePrinciple;
	p.name = "Reuse before buy before build";
	p.status = SpecificationStatus.Approved;
	p.principleOwner = "Chief Architect";
	bool failed;
	try p.validate(); catch (ValidationException e) failed = e.field == "statement";
	assert(failed);
	p.statement = "Existing solutions are reused first";
	p.rationale = "Lower cost and complexity";
	p.validate();
}
