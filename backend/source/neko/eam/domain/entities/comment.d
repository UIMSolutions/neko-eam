/// Comment - entry of the running journal of an architecture element (any entity set): date, author, text.
/// Comments document the current state and changes; they are not edited afterwards (append-only journal).
module neko.eam.domain.entities.comment;

import std.conv : to;
import std.string : strip;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;

/// Longest accepted comment text.
enum maxCommentLength = 4000;

final class Comment {
	string id;
	string elementSet;   /// entity set of the commented element
	string elementId;    /// id of the commented element
	string text;
	string createdAt;    /// date (ISO timestamp, UTC)
	string createdBy;    /// author (authenticated user)

	void validate() const {
		if (elementSet.length == 0 || elementSet == "All")
			throw new ValidationException("elementSet", "A comment belongs to an element of an entity set");
		try elementSet.to!EntitySetName;
		catch (Exception) throw new ValidationException("elementSet", "Unknown entity set '" ~ elementSet ~ "'");
		if (elementId.strip.length == 0)
			throw new ValidationException("elementId", "A comment belongs to an element");
		if (text.strip.length == 0)
			throw new ValidationException("text", "The comment is empty");
		if (text.length > maxCommentLength)
			throw new ValidationException("text", "A comment has at most " ~ maxCommentLength.to!string ~ " characters");
	}
}

unittest {
	auto c = new Comment;
	c.elementSet = "Applications"; c.elementId = "app-crm"; c.text = "  ";
	bool failed;
	try c.validate(); catch (ValidationException e) failed = e.field == "text";
	assert(failed);
	c.text = "Go-live postponed to Q2";
	c.validate();
	c.elementSet = "Nope";
	failed = false;
	try c.validate(); catch (ValidationException e) failed = e.field == "elementSet";
	assert(failed);
}
