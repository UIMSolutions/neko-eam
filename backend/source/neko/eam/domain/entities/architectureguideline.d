/// Architecture guideline - concrete, checkable rule that puts architecture principles into practice
/// (e.g. "REST APIs are described with OpenAPI 3"), optionally naming the standard products to use.
module neko.eam.domain.entities.architectureguideline;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class ArchitectureGuideline {
	mixin ArchitectureElementFields;

	string shortName;                 /// Short Name
	ArchitectureDomain domain = ArchitectureDomain.Application; /// Architecture Domain
	ObligationLevel obligation = ObligationLevel.Recommended; /// Obligation
	SpecificationStatus status = SpecificationStatus.Draft; /// Status
	string specVersion;               /// Version
	string applicability;             /// Applicability
	string verification;              /// Compliance Verification
	string guidelineOwner;            /// Guideline Owner
	@References("Organizations") string ownerOrganizationId; /// Responsible Organization
	@DateField string validFrom;      /// Valid From
	@DateField string validUntil;     /// Valid Until
	@References("ArchitecturePrinciples") string[] principleIds; /// Architecture Principles
	@References("Products") string[] standardProductIds; /// Standard Products
	@References("ITComponents") string[] componentIds; /// IT Components

	void validate() const {
		validateAnnotatedFields(this);
		checkDateOrder("validFrom", validFrom, "validUntil", validUntil);
		if (status == SpecificationStatus.Approved && guidelineOwner.length == 0)
			throw new ValidationException("guidelineOwner", "An approved architecture guideline needs a guideline owner");
		if (obligation == ObligationLevel.Mandatory && principleIds.length == 0)
			throw new ValidationException("principleIds", "A mandatory guideline must be derived from at least one architecture principle");
	}
}

unittest {
	auto g = new ArchitectureGuideline;
	g.name = "OpenAPI for REST interfaces";
	g.obligation = ObligationLevel.Mandatory;
	bool failed;
	try g.validate(); catch (ValidationException e) failed = e.field == "principleIds";
	assert(failed);
	g.principleIds = ["ap-api"];
	g.validate();
}
