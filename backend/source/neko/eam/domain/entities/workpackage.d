/// Work package - smallest planned unit of a project (WBS element) with responsible, schedule, effort,
/// cost, progress and predecessors. Belongs to a project and optionally to one of its sub projects.
module neko.eam.domain.entities.workpackage;

import std.algorithm : canFind;
import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class WorkPackage {
	mixin ArchitectureElementFields;

	string wbsCode;                   /// WBS Code
	@Required @References("Projects") string projectId; /// Project
	@References("SubProjects") string subProjectId; /// Sub Project
	string responsible;               /// Responsible
	WorkPackageStatus status = WorkPackageStatus.NotStarted; /// Status
	@DateField string startDate;      /// Start Date
	@DateField string endDate;        /// End Date
	double plannedEffortDays = 0;     /// Planned Effort (days)
	double actualEffortDays = 0;      /// Actual Effort (days)
	double plannedCost = 0;           /// Planned Cost
	double actualCost = 0;            /// Actual Cost
	int progress;                     /// Progress (%)
	string deliverables;              /// Deliverables
	@References("WorkPackages") string[] predecessorIds; /// Predecessors
	@References("Measures") string[] measureIds; /// Implemented Measures
	@References("Applications") string[] affectedApplicationIds; /// Affected Applications
	bool delayed;                     /// Delayed (derived)

	/// Open work packages whose end date has passed.
	static bool isDelayed(WorkPackageStatus status, string endDate, string today) pure @safe {
		return status != WorkPackageStatus.Completed && status != WorkPackageStatus.Cancelled
			&& endDate.length && endDate < today;
	}

	void validate() const {
		validateAnnotatedFields(this);
		checkDateOrder("startDate", startDate, "endDate", endDate);
		checkRange("progress", progress, 0, 100);
		static foreach (f; ["plannedEffortDays", "actualEffortDays", "plannedCost", "actualCost"])
			if (__traits(getMember, this, f) < 0)
				throw new ValidationException(f, f ~ " must not be negative");
		if (id.length && predecessorIds.canFind(id))
			throw new ValidationException("predecessorIds", "A work package cannot be its own predecessor");
		if (status == WorkPackageStatus.InProgress) {
			if (responsible.length == 0)
				throw new ValidationException("responsible", "A running work package needs a responsible person");
			if (startDate.length == 0)
				throw new ValidationException("startDate", "A running work package needs a start date");
		}
		if (status == WorkPackageStatus.Completed && progress != 100)
			throw new ValidationException("progress", "A completed work package must have a progress of 100 %");
	}
}

unittest {
	auto w = new WorkPackage;
	w.id = "wp-1"; w.name = "Cutover"; w.projectId = "prj-1";
	w.predecessorIds = ["wp-1"];
	bool failed;
	try w.validate(); catch (ValidationException e) failed = e.field == "predecessorIds";
	assert(failed);
	w.predecessorIds = null;
	w.status = WorkPackageStatus.Completed;
	failed = false;
	try w.validate(); catch (ValidationException e) failed = e.field == "progress";
	assert(failed);
	w.progress = 100;
	w.validate();
	assert(WorkPackage.isDelayed(WorkPackageStatus.InProgress, "2026-01-01", "2026-11-12"));
	assert(!WorkPackage.isDelayed(WorkPackageStatus.Completed, "2026-01-01", "2026-11-12"));
}
