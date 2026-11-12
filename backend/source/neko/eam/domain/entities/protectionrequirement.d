/// Protection requirement (Schutzbedarfsfeststellung, BSI 200-2) of one application, business data object or
/// IT component: confidentiality, integrity and availability; the overall level follows the maximum principle.
module neko.eam.domain.entities.protectionrequirement;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class ProtectionRequirement {
	mixin ArchitectureElementFields;

	@References("Applications") string applicationId;   /// Application
	@References("BusinessData") string businessDataId;  /// Business Data
	@References("ITComponents") string componentId;     /// IT Component
	ProtectionLevel confidentiality = ProtectionLevel.Normal; /// Confidentiality
	ProtectionLevel integrity = ProtectionLevel.Normal;       /// Integrity
	ProtectionLevel availability = ProtectionLevel.Normal;    /// Availability
	ProtectionLevel overallLevel = ProtectionLevel.Normal;    /// Overall Protection Level (derived, maximum principle)
	string justification;             /// Justification
	SpecificationStatus status = SpecificationStatus.Draft; /// Status
	string assessedBy;                /// Assessed By
	@DateField string assessmentDate; /// Assessment Date
	@DateField string nextReviewDate; /// Next Review Date
	bool reviewOverdue;               /// Review Overdue (derived)

	void derive() {
		overallLevel = confidentiality;
		if (integrity > overallLevel) overallLevel = integrity;
		if (availability > overallLevel) overallLevel = availability;
	}

	/// Exactly one assessed object.
	string objectKey() const {
		return applicationId.length ? "Applications/" ~ applicationId
			: businessDataId.length ? "BusinessData/" ~ businessDataId : "ITComponents/" ~ componentId;
	}

	void validate() const {
		validateAnnotatedFields(this);
		int objects = (applicationId.length > 0) + (businessDataId.length > 0) + (componentId.length > 0);
		if (objects != 1)
			throw new ValidationException("applicationId", "Assess exactly one object: an application, a business data object or an IT component");
		checkDateOrder("assessmentDate", assessmentDate, "nextReviewDate", nextReviewDate);
		if (status == SpecificationStatus.Approved) {
			if (assessedBy.length == 0 || assessmentDate.length == 0)
				throw new ValidationException("assessedBy", "An approved assessment needs the assessor and the assessment date");
			if (overallLevel > ProtectionLevel.Normal && justification.length == 0)
				throw new ValidationException("justification", "A protection requirement above 'Normal' needs a justification");
		}
	}
}

unittest {
	auto p = new ProtectionRequirement;
	p.name = "CRM";
	bool failed;
	try p.validate(); catch (ValidationException e) failed = e.field == "applicationId";
	assert(failed, "one object");
	p.applicationId = "app-crm";
	p.confidentiality = ProtectionLevel.High;
	p.availability = ProtectionLevel.VeryHigh;
	p.derive();
	assert(p.overallLevel == ProtectionLevel.VeryHigh);
	p.status = SpecificationStatus.Approved; p.assessedBy = "ISB"; p.assessmentDate = "2026-01-10";
	failed = false;
	try p.validate(); catch (ValidationException e) failed = e.field == "justification";
	assert(failed);
}
