/// Service product group - node of a service / product catalogue (catalogue, chapter, service group).
module neko.eam.domain.entities.serviceproductgroup;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class ServiceProductGroup {
	mixin ArchitectureElementFields;

	string shortName;                 /// Short Name
	CatalogType catalogType = CatalogType.BusinessService; /// Catalog Type
	string catalogueManager;          /// Catalogue Manager
	@DateField string releaseDate;    /// Date of Release
	ProductStatus status = ProductStatus.Draft; /// Status
	string catalogVersion;            /// Version
	@References("ServiceProductGroups") string parentId; /// Parent Catalog
	/// "Catalog": full path in the catalogue hierarchy (derived at read time).
	string hierarchyPath;

	void validate() const {
		validateAnnotatedFields(this);
		if (parentId.length && parentId == id)
			throw new ValidationException("parentId", "A catalogue cannot be its own parent");
		if (status == ProductStatus.Released && releaseDate.length == 0)
			throw new ValidationException("releaseDate", "A released catalogue needs a date of release");
	}
}

unittest {
	auto g = new ServiceProductGroup;
	g.name = "Workplace Services";
	g.status = ProductStatus.Released;
	bool failed;
	try g.validate(); catch (ValidationException e) failed = e.field == "releaseDate";
	assert(failed);
	g.releaseDate = "2026-01-01";
	g.validate();
}
