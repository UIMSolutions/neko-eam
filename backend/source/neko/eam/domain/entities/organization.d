/// Organisational unit - owner of applications and capabilities, sponsor of projects,
/// consumer and provider of business / support services.
module neko.eam.domain.entities.organization;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class Organization {
	mixin ArchitectureElementFields;

	OrganizationType orgType = OrganizationType.Department;
	string location;
	@References("Organizations") string parentId;
	string shortName; /// Short Name
	string architect; /// Architect
	string contact; /// Contact
	string stakeholder; /// Stakeholder
	@DateField string startDate; /// Start Date
	@DateField string endDate; /// End Date
	ObjectState status = ObjectState.Active; /// Status
	int totalConsumedBusinessServices; /// Total Consumed Business Services
	int totalProvidedBusinessServices; /// Total Provided Business Services
	int totalProvidedSupportServices; /// Total Provided Support Services
	@References("Enterprises") string enterpriseId; /// Organisation (legal entity)
	string costCenter;                /// Cost Center
	/// "Organisation": full path in the organisation hierarchy (derived at read time).
	string hierarchyPath;
	// derived from the current members at read time
	string headOfUnit;                /// Head of Unit
	int totalMembers;                 /// Members (direct)
	double totalCapacity = 0;         /// Capacity (FTE, direct)

	void validate() const {
		validateAnnotatedFields(this);
		if (parentId.length && parentId == id)
			throw new ValidationException("parentId", "An organization cannot be its own parent");
		checkDateOrder("startDate", startDate, "endDate", endDate);
		static foreach (f; ["totalConsumedBusinessServices", "totalProvidedBusinessServices", "totalProvidedSupportServices"])
			checkRange(f, __traits(getMember, this, f), 0, int.max);
		if (status == ObjectState.Active && endDate.length && isBefore(endDate, todayIso()))
			throw new ValidationException("status", "An organization whose end date has passed cannot be Active");
	}
}

unittest {
	auto o = new Organization;
	o.name = "IT";
	o.startDate = "2020-01-01";
	o.validate();
	o.endDate = "2019-12-31";
	bool failed;
	try o.validate(); catch (ValidationException e) failed = e.field == "endDate";
	assert(failed);
	o.endDate = "2021-01-01";
	failed = false;
	try o.validate(); catch (ValidationException e) failed = e.field == "status";
	assert(failed);
	o.status = ObjectState.Inactive;
	o.validate();
}
