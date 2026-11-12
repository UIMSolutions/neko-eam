/// Application (application component) - the central element of the application portfolio.
module neko.eam.domain.entities.application;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class Application {
	mixin ArchitectureElementFields;

	string release;                                  /// release / version label
	LifecycleStatus status = LifecycleStatus.Active;
	Criticality criticality = Criticality.Medium;
	TimeCategory timeCategory = TimeCategory.Tolerate;
	int businessValue = 3;                           /// 1 (low) .. 5 (high)
	int technicalFit = 3;                            /// 1 (poor) .. 5 (excellent)
	double annualCost = 0;                           /// total cost of ownership per year
	@DateField string goLiveDate;
	@DateField string retirementDate;
	@References("Organizations") string ownerOrganizationId;
	@References("BusinessCapabilities") string[] capabilityIds;
	@References("ITComponents") string[] componentIds;
	string levelId; /// Level ID
	ObjectState objectState = ObjectState.Active; /// Object State
	@References("ApplicationGroups") string applicationGroupId; /// Parent Application Group
	string stakeholder; /// Stakeholder
	@References("Products") string[] usedProductIds; /// Used Products
	@References("Products") string[] assignedProductIds; /// Assigned Products
	int totalUsedProducts; /// Insgesamt genutzte Produkte
	int totalAssignedProducts; /// Insgesamt zugewiesene Produkte

	/// Derived values: product totals (distinct product references).
	void derive() @safe {
		import std.algorithm : sort, uniq, count;
		totalUsedProducts = cast(int) usedProductIds.dup.sort.uniq.count;
		totalAssignedProducts = cast(int) assignedProductIds.dup.sort.uniq.count;
	}

	/// true while the application is in productive use.
	bool isOperational() const @safe pure nothrow {
		return status == LifecycleStatus.Active || status == LifecycleStatus.PhaseOut;
	}

	void validate() const {
		validateAnnotatedFields(this);
		checkRange("businessValue", businessValue, 1, 5);
		checkRange("technicalFit", technicalFit, 1, 5);
		if (annualCost < 0)
			throw new ValidationException("annualCost", "annualCost must not be negative");
		checkDateOrder("goLiveDate", goLiveDate, "retirementDate", retirementDate);
		if (status == LifecycleStatus.Retired && retirementDate.length == 0)
			throw new ValidationException("retirementDate", "A retired application needs a retirementDate");
		if (status == LifecycleStatus.Active && objectState == ObjectState.Archived)
			throw new ValidationException("objectState", "An active application cannot be archived");
	}
}

unittest {
	auto app = new Application;
	app.name = "CRM";
	app.validate();
	app.businessValue = 9;
	bool failed;
	try app.validate(); catch (ValidationException e) failed = e.field == "businessValue";
	assert(failed);
	app.businessValue = 3;
	app.usedProductIds = ["p1", "p2", "p1"];
	app.derive();
	assert(app.totalUsedProducts == 2 && app.totalAssignedProducts == 0);
}
