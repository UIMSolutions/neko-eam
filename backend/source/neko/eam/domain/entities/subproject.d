/// Sub project - part of a project with its own manager, schedule and budget. Sub projects can be nested;
/// work packages belong to a project and optionally to one of its sub projects.
module neko.eam.domain.entities.subproject;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class SubProject {
	mixin ArchitectureElementFields;

	string shortName;                 /// Short Name
	@Required @References("Projects") string projectId; /// Project
	@References("SubProjects") string parentSubProjectId; /// Parent Sub Project
	string subProjectManager;         /// Sub Project Manager
	ProjectStatus status = ProjectStatus.Proposed; /// Status
	@DateField string startDate;      /// Start Date
	@DateField string endDate;        /// End Date
	double budget = 0;                /// Budget
	@References("Organizations") string ownerOrganizationId; /// Responsible Organization
	@References("Applications") string[] affectedApplicationIds; /// Affected Applications
	/// "Sub Project": path project / parent sub projects / sub project (derived at read time).
	string hierarchyPath;
	int totalWorkPackages;            /// Total Work Packages (rolled up)
	double plannedEffortDays = 0;     /// Planned Effort (days, rolled up)
	int progress;                     /// Progress (%, rolled up)

	void validate() const {
		validateAnnotatedFields(this);
		if (parentSubProjectId.length && parentSubProjectId == id)
			throw new ValidationException("parentSubProjectId", "A sub project cannot be its own parent");
		if (budget < 0)
			throw new ValidationException("budget", "budget must not be negative");
		checkDateOrder("startDate", startDate, "endDate", endDate);
		if (status == ProjectStatus.InProgress && subProjectManager.length == 0)
			throw new ValidationException("subProjectManager", "A running sub project needs a sub project manager");
	}
}

unittest {
	auto s = new SubProject;
	s.name = "Data migration";
	bool failed;
	try s.validate(); catch (ValidationException e) failed = e.field == "projectId";
	assert(failed);
	s.projectId = "prj-1";
	s.status = ProjectStatus.InProgress;
	failed = false;
	try s.validate(); catch (ValidationException e) failed = e.field == "subProjectManager";
	assert(failed);
	s.subProjectManager = "A. Krüger";
	s.validate();
}
