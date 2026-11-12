/// Generic, annotation driven validation of entity fields.
module neko.eam.domain.entities.validation;

import std.traits : hasUDA, FieldNameTuple;
import std.string : strip;
import neko.eam.domain.types;
import neko.eam.domain.exceptions;

/// Checks `@Required` and `@DateField` constraints of all fields of `entity`.
void validateAnnotatedFields(T)(const T entity) {
	static foreach (name; FieldNameTuple!T) {
		{
			alias member = __traits(getMember, T, name);
			auto value = __traits(getMember, entity, name);
			static if (hasUDA!(member, Required)) {
				static if (is(typeof(value) : const(char)[])) {
					if (value.strip.length == 0)
						throw new ValidationException(name, "Field '" ~ name ~ "' is required");
				}
			}
			static if (hasUDA!(member, DateField)) {
				if (!isIsoDateOrEmpty(value))
					throw new ValidationException(name, "Field '" ~ name ~ "' must be an ISO date (YYYY-MM-DD), got '" ~ value ~ "'");
			}
		}
	}
}

/// Ensures `value` is within [min, max].
void checkRange(string field, long value, long min, long max) {
	import std.conv : to;
	if (value < min || value > max)
		throw new ValidationException(field, "Field '" ~ field ~ "' must be between " ~ min.to!string ~ " and " ~ max.to!string);
}

/// Ensures `from` is not after `to` (both optional).
void checkDateOrder(string fromField, string from, string toField, string to) {
	if (from.length && to.length && to < from)
		throw new ValidationException(toField, "'" ~ toField ~ "' must not be before '" ~ fromField ~ "'");
}
