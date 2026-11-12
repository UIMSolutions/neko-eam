/// Report - a stored query over one entity set: columns, filter ($filter syntax), sort order, optional
/// grouping with count / sum. Executed with the rights of the caller.
module neko.eam.domain.entities.report;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class Report {
	mixin ArchitectureElementFields;

	string category;                  /// Category
	EntitySetName entitySet = EntitySetName.Applications; /// Entity Set
	string[] columns;                 /// Columns (field names; empty = list columns)
	string filter;                    /// Filter (OData $filter syntax)
	string orderBy;                   /// Order By (OData $orderby syntax)
	string groupBy;                   /// Group By (field)
	string sumField;                  /// Sum Field (numeric, per group)
	int maxRows;                      /// Max Rows (0 = all)
	string reportOwner;               /// Report Owner

	void validate() const {
		validateAnnotatedFields(this);
		if (entitySet == EntitySetName.All)
			throw new ValidationException("entitySet", "A report needs one entity set");
		checkRange("maxRows", maxRows, 0, 100_000);
		if (sumField.length && groupBy.length == 0)
			throw new ValidationException("sumField", "A sum per group needs a 'Group By' field");
	}
}

/// Report book (Berichtsmappe) - several reports exported together (one sheet / section per report).
final class ReportBook {
	mixin ArchitectureElementFields;

	string audience;                  /// Audience
	string reportOwner;               /// Report Owner
	@References("Reports") string[] reportIds; /// Reports (in this order)

	void validate() const {
		validateAnnotatedFields(this);
		if (reportIds.length == 0)
			throw new ValidationException("reportIds", "A report book needs at least one report");
	}
}
