/// Process step - activity of an IT process with responsible unit, supporting applications and automation level.
module neko.eam.domain.entities.processstep;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class ProcessStep {
	mixin ArchitectureElementFields;

	@Required @References("ITProcesses") string processId; /// IT Process
	int sequenceNo = 10;              /// Sequence No. (unique per process)
	StepType stepType = StepType.Activity; /// Step Type
	AutomationLevel automationLevel = AutomationLevel.Manual; /// Automation Level
	string performerRole;             /// Performer Role
	@References("Organizations") string responsibleOrganizationId; /// Responsible Organization
	@References("Applications") string[] applicationIds; /// Supporting Applications
	double durationHours = 0;         /// Duration (hours)
	string inputs;                    /// Inputs
	string outputs;                   /// Outputs

	void validate() const {
		validateAnnotatedFields(this);
		checkRange("sequenceNo", sequenceNo, 1, 9999);
		if (durationHours < 0) throw new ValidationException("durationHours", "The duration must not be negative");
		if ((stepType == StepType.Automated || automationLevel != AutomationLevel.Manual) && applicationIds.length == 0)
			throw new ValidationException("applicationIds", "An automated step needs at least one supporting application");
	}
}

unittest {
	auto s = new ProcessStep;
	s.name = "Auto-assign ticket"; s.processId = "itp-1"; s.automationLevel = AutomationLevel.Automated;
	bool failed;
	try s.validate(); catch (ValidationException e) failed = e.field == "applicationIds";
	assert(failed);
	s.applicationIds = ["app-1"];
	s.validate();
}
