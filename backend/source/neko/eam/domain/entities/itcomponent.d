/// IT component - technology (software product, platform, database, hardware) used by applications.
module neko.eam.domain.entities.itcomponent;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class ITComponent {
	mixin ArchitectureElementFields;

	string vendor;
	string release;
	TechnologyCategory category = TechnologyCategory.Software;
	LifecycleStatus status = LifecycleStatus.Active;
	@DateField string endOfSupportDate;
	double licenseCost = 0;

	/// true if the vendor support has ended at `today` (ISO date) or the component is phased out.
	bool isOutdated(string today) const @safe pure nothrow {
		return status == LifecycleStatus.PhaseOut || status == LifecycleStatus.Retired
			|| (endOfSupportDate.length && endOfSupportDate < today);
	}

	void validate() const {
		validateAnnotatedFields(this);
		if (licenseCost < 0)
			throw new ValidationException("licenseCost", "licenseCost must not be negative");
	}
}

unittest {
	auto c = new ITComponent;
	c.name = "Oracle 11g";
	c.endOfSupportDate = "2020-12-31";
	assert(c.isOutdated("2026-01-01"));
	assert(!c.isOutdated("2019-01-01"));
}
