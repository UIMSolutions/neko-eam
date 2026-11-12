/// Security control (Sicherheitsmaßnahme) from ISO 27001 Annex A, BSI IT-Grundschutz, NIST, CIS or internal:
/// type, implementation status, effectiveness, owner and due date; overdue and mitigated risks are derived.
module neko.eam.domain.entities.securitycontrol;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class SecurityControl {
	mixin ArchitectureElementFields;

	string controlReference;          /// Control Reference (e.g. "ISO 27001 A.8.13", "OPS.1.1.5.A3")
	ControlFramework framework = ControlFramework.ISO27001; /// Framework
	ControlType controlType = ControlType.Preventive; /// Control Type
	ImplementationStatus implementationStatus = ImplementationStatus.Planned; /// Implementation Status
	int effectiveness;                /// Effectiveness (1-5, 0 = not assessed)
	string controlOwner;              /// Control Owner
	@DateField string dueDate;        /// Due Date
	@DateField string lastReviewDate; /// Last Review
	@References("Applications") string[] applicationIds;  /// Applications
	@References("ITComponents") string[] componentIds;    /// IT Components
	bool overdue;                     /// Overdue (derived)
	int mitigatedRisks;               /// Mitigated Risks (derived)

	/// Not implemented (and applicable) after its due date.
	static bool isOverdue(ImplementationStatus s, string dueDate, string today) pure @safe {
		return (s == ImplementationStatus.Planned || s == ImplementationStatus.InProgress) && dueDate.length && dueDate < today;
	}

	void validate() const {
		validateAnnotatedFields(this);
		checkRange("effectiveness", effectiveness, 0, 5);
		if (implementationStatus == ImplementationStatus.Implemented && controlOwner.length == 0)
			throw new ValidationException("controlOwner", "An implemented control needs a control owner");
		if (implementationStatus == ImplementationStatus.NotApplicable && description.length == 0)
			throw new ValidationException("description", "A control that is not applicable needs a justification in the description");
		if (implementationStatus == ImplementationStatus.InProgress && dueDate.length == 0)
			throw new ValidationException("dueDate", "A control in progress needs a due date");
	}
}

unittest {
	auto c = new SecurityControl;
	c.name = "Backup"; c.implementationStatus = ImplementationStatus.NotApplicable;
	bool failed;
	try c.validate(); catch (ValidationException e) failed = e.field == "description";
	assert(failed);
	assert(SecurityControl.isOverdue(ImplementationStatus.InProgress, "2026-01-01", "2026-11-12"));
	assert(!SecurityControl.isOverdue(ImplementationStatus.Implemented, "2026-01-01", "2026-11-12"));
}
