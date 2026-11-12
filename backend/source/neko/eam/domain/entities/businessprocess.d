/// Business process - how the business performs its capabilities (process map hierarchy).
module neko.eam.domain.entities.businessprocess;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class BusinessProcess {
	mixin ArchitectureElementFields;

	string levelId;                   /// Level ID
	string processManager;            /// Process Manager
	string processOwner;              /// Process Owner
	LifecycleStatus status = LifecycleStatus.Active; /// Status
	@References("BusinessProcesses") string parentProcessId; /// Parent Business Process
	/// "Business Process": full path in the process map (derived at read time).
	string hierarchyPath;

	void validate() const {
		validateAnnotatedFields(this);
		if (parentProcessId.length && parentProcessId == id)
			throw new ValidationException("parentProcessId", "A business process cannot be its own parent");
		if (status == LifecycleStatus.Active && processOwner.length == 0)
			throw new ValidationException("processOwner", "An active business process needs a process owner");
	}
}

unittest {
	auto p = new BusinessProcess;
	p.name = "Order to Cash";
	bool failed;
	try p.validate(); catch (ValidationException e) failed = e.field == "processOwner";
	assert(failed);
	p.status = LifecycleStatus.Plan;
	p.validate();
}
