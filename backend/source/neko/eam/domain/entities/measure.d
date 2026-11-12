/// Measure - planned change of the IT landscape (introduce, migrate, retire, ...), derived from strategic
/// guidelines and service capability gaps, affecting applications and IT components.
module neko.eam.domain.entities.measure;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class Measure {
	mixin ArchitectureElementFields;

	string shortName;                 /// Short Name
	MeasureType measureType = MeasureType.Modernize; /// Measure Type
	PlanningPriority priority = PlanningPriority.Medium; /// Priority
	PlanningStatus status = PlanningStatus.Draft; /// Status
	int progress;                     /// Progress (%)
	string responsible;               /// Responsible
	@References("Organizations") string ownerOrganizationId; /// Responsible Organization
	@DateField string startDate;      /// Start Date
	@DateField string endDate;        /// End Date
	double estimatedCost = 0;         /// Estimated Cost
	string expectedBenefit;           /// Expected Benefit
	@References("MeasureGroups") string measureGroupId; /// Measure Group
	@References("Projects") string projectId; /// Implementing Project
	@References("StrategicGuidelines") string[] strategicGuidelineIds; /// Strategic Guidelines
	@References("ServiceCapabilities") string[] serviceCapabilityIds; /// Service Capabilities
	@References("Applications") string[] affectedApplicationIds; /// Affected Applications
	@References("ITComponents") string[] affectedComponentIds; /// Affected IT Components

	void validate() const {
		validateAnnotatedFields(this);
		if (estimatedCost < 0)
			throw new ValidationException("estimatedCost", "estimated cost must not be negative");
		checkRange("progress", progress, 0, 100);
		checkDateOrder("startDate", startDate, "endDate", endDate);
		if ((status == PlanningStatus.Approved || status == PlanningStatus.InProgress) && responsible.length == 0)
			throw new ValidationException("responsible", "An approved or running measure needs a responsible person");
		if (status == PlanningStatus.InProgress && startDate.length == 0)
			throw new ValidationException("startDate", "A running measure needs a start date");
		if (status == PlanningStatus.Completed && progress != 100)
			throw new ValidationException("progress", "A completed measure must have a progress of 100 %");
		if ((measureType == MeasureType.Retire || measureType == MeasureType.Migrate)
				&& affectedApplicationIds.length == 0 && affectedComponentIds.length == 0)
			throw new ValidationException("affectedApplicationIds",
				"A retire or migrate measure must name the affected applications or IT components");
	}
}

unittest {
	auto m = new Measure;
	m.name = "Retire Oracle 11g";
	m.measureType = MeasureType.Retire;
	bool failed;
	try m.validate(); catch (ValidationException e) failed = e.field == "affectedApplicationIds";
	assert(failed);
	m.affectedComponentIds = ["tc-oracle11"];
	m.validate();
	m.status = PlanningStatus.Completed;
	m.responsible = "M. Weber";
	failed = false;
	try m.validate(); catch (ValidationException e) failed = e.field == "progress";
	assert(failed);
	m.progress = 100;
	m.validate();
}
