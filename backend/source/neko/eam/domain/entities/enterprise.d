/// Enterprise ("Organisation") - legal entity (group, holding, subsidiary) that owns organisational units.
/// Enterprises form the group structure via parent and ownership share.
module neko.eam.domain.entities.enterprise;

import std.algorithm : startsWith;
import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class Enterprise {
	mixin ArchitectureElementFields;

	string shortName;                 /// Short Name
	string legalForm;                 /// Legal Form (e.g. SE, GmbH, AG)
	string registrationNumber;        /// Commercial Register Number
	string vatId;                     /// VAT ID
	string headquarters;              /// Headquarters
	string country;                   /// Country
	string industry;                  /// Industry
	string website;                   /// Website
	@DateField string foundingDate;   /// Founding Date
	ObjectState status = ObjectState.Active; /// Status
	@References("Enterprises") string parentEnterpriseId; /// Parent Organisation
	double ownershipShare = 0;        /// Ownership Share (%) held by the parent
	/// Managing Director: head of the top-level unit(s) of the organisation (derived from the members).
	string managingDirector;
	/// "Organisation": path in the group structure (derived at read time).
	string hierarchyPath;
	int totalUnits;                   /// Organisational Units (derived)
	int totalMembers;                 /// Members (derived, current)

	void validate() const {
		validateAnnotatedFields(this);
		if (parentEnterpriseId.length && parentEnterpriseId == id)
			throw new ValidationException("parentEnterpriseId", "An organisation cannot be its own parent");
		if (ownershipShare < 0 || ownershipShare > 100)
			throw new ValidationException("ownershipShare", "The ownership share must be between 0 and 100 %");
		if (ownershipShare > 0 && parentEnterpriseId.length == 0)
			throw new ValidationException("ownershipShare", "An ownership share needs a parent organisation");
		if (website.length && !website.startsWith("http://") && !website.startsWith("https://"))
			throw new ValidationException("website", "Field 'website' must be an http(s) URL");
	}
}

unittest {
	auto e = new Enterprise;
	e.name = "ACME IT Services GmbH";
	e.ownershipShare = 100;
	bool failed;
	try e.validate(); catch (ValidationException x) failed = x.field == "ownershipShare";
	assert(failed);
	e.parentEnterpriseId = "ent-acme";
	e.validate();
}
