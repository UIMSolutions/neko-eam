/// Comment journal stored in the tenant's document storage (collection "Comments") - part of every backup.
module neko.eam.persistence.repositories.commentrepository;

import std.algorithm : filter, sort;
import std.array : array;
import vibe.data.json;
import neko.eam.domain.entities.comment;
import neko.eam.ports.repositories : ICommentRepository;
import neko.eam.ports.storages : IDocumentStorage;

class CommentRepository : ICommentRepository {
	enum collection = "Comments";
	private IDocumentStorage _storage;
	private Comment[] _all; // cached; written through on every change

	this(IDocumentStorage storage) {
		_storage = storage;
		foreach (d; storage.load(collection)) _all ~= fromJson(d);
	}

	Comment[] forElement(string elementSet, string elementId) {
		auto r = _all.filter!(c => c.elementSet == elementSet && c.elementId == elementId).array;
		r.sort!((a, b) => a.createdAt < b.createdAt || (a.createdAt == b.createdAt && a.id < b.id));
		return r;
	}

	Comment find(string id) {
		foreach (c; _all) if (c.id == id) return c;
		return null;
	}

	void save(Comment comment) {
		Comment[] next;
		bool replaced;
		foreach (c; _all) {
			if (c.id == comment.id) { next ~= comment; replaced = true; }
			else next ~= c;
		}
		if (!replaced) next ~= comment;
		_all = next;
		flush();
	}

	void remove(string id) {
		_all = _all.filter!(c => c.id != id).array;
		flush();
	}

	size_t removeForElement(string elementSet, string elementId) {
		auto before = _all.length;
		_all = _all.filter!(c => !(c.elementSet == elementSet && c.elementId == elementId)).array;
		if (_all.length != before) flush();
		return before - _all.length;
	}

	size_t count() { return _all.length; }

	private void flush() {
		Json[] docs;
		foreach (c; _all) docs ~= toJson(c);
		_storage.store(collection, docs);
	}

	private static Json toJson(Comment c) {
		auto j = Json.emptyObject;
		j["schemaVersion"] = 1;
		static foreach (f; ["id", "elementSet", "elementId", "text", "createdAt", "createdBy"]) j[f] = __traits(getMember, c, f);
		return j;
	}

	private static Comment fromJson(Json j) {
		auto c = new Comment;
		static foreach (f; ["id", "elementSet", "elementId", "text", "createdAt", "createdBy"]) __traits(getMember, c, f) = j[f].opt!string("");
		return c;
	}
}
