/// Measure group - bundles measures of the IT landscape planning (planning programme, roadmap stream).
/// Measure count and cost totals are rolled up from the measures of the subtree at read time.
module neko.eam.domain.entities.measuregroup;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class MeasureGroup {
	mixin ArchitectureElementFields;

	string shortName;                 /// Short Name
	PlanningStatus status = PlanningStatus.Draft; /// Status
	string responsible;               /// Responsible
	@References("Organizations") string ownerOrganizationId; /// Responsible Organization
	@DateField string startDate;      /// Planning Period Start
	@DateField string endDate;        /// Planning Period End
	double budget = 0;                /// Budget
	@References("MeasureGroups") string parentGroupId; /// Parent Measure Group
	@References("StrategicGuidelines") string[] strategicGuidelineIds; /// Strategic Guidelines
	/// "Measure Group": full path (derived at read time).
	string hierarchyPath;
	int totalMeasures;                /// Total Measures (rolled up)
	double totalEstimatedCost = 0;    /// Total Estimated Cost (rolled up)

	void validate() const {
		validateAnnotatedFields(this);
		if (parentGroupId.length && parentGroupId == id)
			throw new ValidationException("parentGroupId", "A measure group cannot be its own parent");
		if (budget < 0)
			throw new ValidationException("budget", "budget must not be negative");
		checkDateOrder("startDate", startDate, "endDate", endDate);
		if (status == PlanningStatus.Approved && responsible.length == 0)
			throw new ValidationException("responsible", "An approved measure group needs a responsible person");
	}
}

unittest {
	auto g = new MeasureGroup;
	g.name = "Cloud Transformation 2027";
	g.budget = -1;
	bool failed;
	try g.validate(); catch (ValidationException e) failed = e.field == "budget";
	assert(failed);
	g.budget = 100;
	g.validate();
}
