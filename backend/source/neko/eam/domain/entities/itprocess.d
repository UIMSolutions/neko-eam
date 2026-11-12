/// IT process (ITIL practice / COBIT process) - how IT delivers and supports its services. Steps and KPIs
/// refer to it; the KPI status (worst KPI) and the hierarchy path are derived at read time.
module neko.eam.domain.entities.itprocess;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class ITProcess {
	mixin ArchitectureElementFields;

	string shortName;                 /// Short Name
	string levelId;                   /// Level ID
	ProcessFramework framework = ProcessFramework.ITIL4; /// Framework
	LifecycleStatus status = LifecycleStatus.Active; /// Status
	string processOwner;              /// Process Owner
	string processManager;            /// Process Manager
	@References("Organizations") string ownerOrganizationId; /// Responsible Organization
	int currentMaturity = 1;          /// Current Maturity (1-5)
	int targetMaturity = 3;           /// Target Maturity (1-5)
	string purpose;                   /// Purpose
	@References("ITProcesses") string parentProcessId; /// Parent IT Process
	@References("BusinessProcesses") string[] businessProcessIds; /// Supported Business Processes
	@References("ServiceProductGroups") string[] serviceProductGroupIds; /// Services
	/// "IT Process": hierarchy path (derived at read time).
	string hierarchyPath;
	int totalSteps;                   /// Steps (derived)
	KpiStatus kpiStatus = KpiStatus.NoData; /// KPI Status (derived: worst KPI)

	void validate() const {
		validateAnnotatedFields(this);
		if (parentProcessId.length && parentProcessId == id)
			throw new ValidationException("parentProcessId", "An IT process cannot be its own parent");
		checkRange("currentMaturity", currentMaturity, 1, 5);
		checkRange("targetMaturity", targetMaturity, 1, 5);
		if (status == LifecycleStatus.Active && processOwner.length == 0)
			throw new ValidationException("processOwner", "An active IT process needs a process owner");
	}
}
