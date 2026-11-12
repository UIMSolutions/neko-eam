/// Business data - information object of the business (data catalogue), classified by DPIA.
module neko.eam.domain.entities.businessdata;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class BusinessData {
	mixin ArchitectureElementFields;

	string dataVersion;               /// Version
	@References("BusinessCapabilities") string capabilityId; /// Business Capability
	string businessObject;            /// Business Object
	DpiaRating dpiaRating = DpiaRating.NotAssessed; /// DPIA Rating
	@References("InformationFlows") string[] informationFlowIds; /// Information Flows
	@References("Organizations") string ownerOrganizationId; /// Owner

	void validate() const {
		validateAnnotatedFields(this);
		if ((dpiaRating == DpiaRating.Medium || dpiaRating == DpiaRating.High) && ownerOrganizationId.length == 0)
			throw new ValidationException("ownerOrganizationId", "Business data with a medium or high DPIA rating needs an owner");
	}
}

unittest {
	auto d = new BusinessData;
	d.name = "Customer";
	d.dpiaRating = DpiaRating.High;
	bool failed;
	try d.validate(); catch (ValidationException e) failed = e.field == "ownerOrganizationId";
	assert(failed);
	d.ownerOrganizationId = "org";
	d.validate();
}
