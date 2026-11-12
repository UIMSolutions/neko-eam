/// Project - a transformation initiative that changes the architecture (work package).
module neko.eam.domain.entities.project;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class Project {
	mixin ArchitectureElementFields;

	ProjectStatus status = ProjectStatus.Proposed;
	@DateField string startDate;
	@DateField string endDate;
	double budget = 0;
	@References("Organizations") string sponsorOrganizationId;
	@References("Applications") string[] affectedApplicationIds;
	string projectNumber;             /// Project Number
	string projectManager;            /// Project Manager
	PlanningPriority priority = PlanningPriority.Medium; /// Priority
	ProjectPhase phase = ProjectPhase.Initiation; /// Phase
	double actualCost = 0;            /// Actual Cost
	// rolled up from sub projects and work packages at read time
	int totalSubProjects;             /// Total Sub Projects
	int totalWorkPackages;            /// Total Work Packages
	double plannedEffortDays = 0;     /// Planned Effort (days)
	int progress;                     /// Progress (%)

	void validate() const {
		validateAnnotatedFields(this);
		if (budget < 0)
			throw new ValidationException("budget", "budget must not be negative");
		checkDateOrder("startDate", startDate, "endDate", endDate);
		if (actualCost < 0)
			throw new ValidationException("actualCost", "actual cost must not be negative");
		if (status == ProjectStatus.Completed && endDate.length == 0)
			throw new ValidationException("endDate", "A completed project needs an end date");
	}
}
