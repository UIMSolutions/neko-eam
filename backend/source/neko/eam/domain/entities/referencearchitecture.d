/// Reference architecture - reusable blueprint for a solution type (building blocks, standard products,
/// principles and guidelines it follows). Reference architectures can be refined hierarchically.
module neko.eam.domain.entities.referencearchitecture;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class ReferenceArchitecture {
	mixin ArchitectureElementFields;

	string shortName;                 /// Short Name
	ArchitectureDomain domain = ArchitectureDomain.Application; /// Architecture Domain
	SpecificationStatus status = SpecificationStatus.Draft; /// Status
	string specVersion;               /// Version
	string scopeDescription;                     /// Scope
	string architect;                 /// Architect
	@References("Organizations") string ownerOrganizationId; /// Responsible Organization
	@DateField string validFrom;      /// Valid From
	@DateField string validUntil;     /// Valid Until
	@References("ReferenceArchitectures") string parentId; /// Parent Reference Architecture
	@References("ArchitecturePrinciples") string[] principleIds; /// Architecture Principles
	@References("ArchitectureGuidelines") string[] guidelineIds; /// Architecture Guidelines
	@References("BusinessCapabilities") string[] capabilityIds; /// Business Capabilities
	@References("ITComponents") string[] componentIds; /// Building Blocks (IT Components)
	@References("Products") string[] standardProductIds; /// Standard Products
	@References("Applications") string[] applicationIds; /// Implementing Applications
	/// "Reference Architecture": full path (derived at read time).
	string hierarchyPath;
	int totalDocuments;               /// Total Documents (derived)

	void validate() const {
		validateAnnotatedFields(this);
		if (parentId.length && parentId == id)
			throw new ValidationException("parentId", "A reference architecture cannot be its own parent");
		checkDateOrder("validFrom", validFrom, "validUntil", validUntil);
		if (status == SpecificationStatus.Approved) {
			if (architect.length == 0)
				throw new ValidationException("architect", "An approved reference architecture needs an architect");
			if (principleIds.length == 0 && guidelineIds.length == 0)
				throw new ValidationException("guidelineIds", "An approved reference architecture must follow at least one principle or guideline");
		}
	}
}

unittest {
	auto r = new ReferenceArchitecture;
	r.name = "Cloud-native web application";
	r.status = SpecificationStatus.Approved;
	r.architect = "M. Weber";
	bool failed;
	try r.validate(); catch (ValidationException e) failed = e.field == "guidelineIds";
	assert(failed);
	r.guidelineIds = ["ag-openapi"];
	r.validate();
}
