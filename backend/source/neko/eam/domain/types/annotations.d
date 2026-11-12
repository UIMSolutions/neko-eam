/// User defined attributes that describe the EAM meta model on entity fields.
module neko.eam.domain.types.annotations;

/// Marks a field as reference to elements of another kind (entity set name).
/// Works for `string` (single reference) and `string[]` (multi reference).
struct References {
	string kind;
}

/// Marks a string field as ISO-8601 calendar date (YYYY-MM-DD). Empty means "not set".
struct DateField {
}

/// Marks a field as mandatory (must not be empty).
struct Required {
}

/// Common fields of every architecture element (mixed into each entity).
mixin template ArchitectureElementFields() {
	/// Technical identity of the element.
	string id;
	/// Human readable name (mandatory).
	@Required string name;
	/// Free text description.
	string description;
	/// ISO timestamp of creation (set by use cases).
	string createdAt;
	/// User who created the element (set by use cases).
	string createdBy;
	/// ISO timestamp of the last modification (set by use cases).
	string modifiedAt;
	/// User who performed the last modification (set by use cases).
	string modifiedBy;
}
