/// Business exceptions of the EAM domain.
module neko.eam.domain.exceptions;

/// Base class of all business exceptions.
class DomainException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) @safe pure nothrow {
		super(msg, file, line);
	}
}

/// A business rule / field validation failed.
class ValidationException : DomainException {
	string field;
	this(string field, string msg, string file = __FILE__, size_t line = __LINE__) @safe pure nothrow {
		this.field = field;
		super(msg, file, line);
	}
}

/// A requested element does not exist.
class EntityNotFoundException : DomainException {
	string kind, id;
	this(string kind, string id, string file = __FILE__, size_t line = __LINE__) @safe pure {
		this.kind = kind;
		this.id = id;
		super(kind ~ " '" ~ id ~ "' not found", file, line);
	}
}

/// An element with the same identity already exists.
class ConflictException : DomainException {
	this(string msg, string file = __FILE__, size_t line = __LINE__) @safe pure nothrow {
		super(msg, file, line);
	}
}

/// A reference points to a missing element, or an element is still referenced.
class ReferentialIntegrityException : DomainException {
	this(string msg, string file = __FILE__, size_t line = __LINE__) @safe pure nothrow {
		super(msg, file, line);
	}
}

/// The caller lacks the permission for an operation on an entity set.
class AccessDeniedException : DomainException {
	string setName;
	this(string setName, string msg, string file = __FILE__, size_t line = __LINE__) @safe pure nothrow {
		this.setName = setName;
		super(msg, file, line);
	}
}
