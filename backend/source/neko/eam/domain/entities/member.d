/// Member - person assigned to an organisational unit (function, capacity, period, line manager),
/// optionally linked to the user account of the access management.
module neko.eam.domain.entities.member;

import std.algorithm : canFind;
import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class Member {
	mixin ArchitectureElementFields;

	string personnelNumber;           /// Personnel Number (unique)
	string jobTitle;                  /// Job Title
	@Required @References("Organizations") string organizationId; /// Organisational Unit
	MemberFunction memberFunction = MemberFunction.Employee; /// Function
	EmploymentType employmentType = EmploymentType.Internal; /// Employment Type
	int capacity = 100;               /// Capacity (%)
	string email;                     /// E-Mail
	string phone;                     /// Phone
	string location;                  /// Location
	@DateField string startDate;      /// Start Date
	@DateField string endDate;        /// End Date
	@References("Members") string managerId; /// Line Manager
	@References("Users") string userId; /// User Account
	bool current;                     /// Current (derived: today within start / end)

	/// Assigned at `today` (ISO date).
	bool isCurrent(string today) const pure @safe {
		return (startDate.length == 0 || startDate <= today) && (endDate.length == 0 || endDate >= today);
	}

	void validate() const {
		validateAnnotatedFields(this);
		checkDateOrder("startDate", startDate, "endDate", endDate);
		checkRange("capacity", capacity, 1, 100);
		if (managerId.length && managerId == id)
			throw new ValidationException("managerId", "A member cannot be their own line manager");
		if (email.length && !email.canFind('@'))
			throw new ValidationException("email", "'" ~ email ~ "' is not an e-mail address");
		if (employmentType != EmploymentType.Internal && endDate.length == 0)
			throw new ValidationException("endDate", "External members, contractors and trainees need an end date");
	}
}

unittest {
	auto m = new Member;
	m.id = "m1"; m.name = "Anna Krüger"; m.organizationId = "org-it";
	m.capacity = 0;
	bool failed;
	try m.validate(); catch (ValidationException e) failed = e.field == "capacity";
	assert(failed);
	m.capacity = 80;
	m.employmentType = EmploymentType.External;
	failed = false;
	try m.validate(); catch (ValidationException e) failed = e.field == "endDate";
	assert(failed);
	m.endDate = "2026-12-31";
	m.validate();
	assert(m.isCurrent("2026-11-12") && !m.isCurrent("2027-01-01"));
}
