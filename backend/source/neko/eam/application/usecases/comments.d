/// Running comments (journal) of the elements of all entity sets.
///
/// The interactor is created twice: unrestricted on the plain use cases (composition root) and, per caller,
/// on the checked use cases (SecuredEamFacade) - then the element look-up enforces read access and deleting
/// other users' comments needs the delete permission on the element's set.
module neko.eam.application.usecases.comments;

import std.algorithm : map, reverse;
import std.array : array;
import std.datetime : Clock;
import std.uuid : randomUUID;
import neko.eam.domain;
import neko.eam.application.dtos;
import neko.eam.ports.repositories;
import neko.eam.ports.usecases;

class CommentsInteractor : IComments {
	private {
		IEamUseCases _uc;               // element look-up (checked for callers)
		ICommentRepository _repo;       // set on the unrestricted instance
		IComments _inner;               // set on a checked instance
		bool delegate(string set) _mayDeleteAny;
		void delegate(Comment) _onAdded;  // unrestricted instance: notifications
	}

	/// Unrestricted instance on the plain use cases; `onAdded` is called after a comment was stored.
	this(IEamUseCases uc, ICommentRepository repo, void delegate(Comment) onAdded = null) {
		_uc = uc; _repo = repo; _mayDeleteAny = (string) => true; _onAdded = onAdded;
	}

	/// Checked instance: `uc` are the caller's use cases, `inner` the unrestricted instance.
	this(IEamUseCases uc, IComments inner, bool delegate(string set) mayDeleteAny) {
		_uc = uc; _inner = inner; _mayDeleteAny = mayDeleteAny;
	}

	CommentDto[] list(string elementSet, string elementId, string actor = "") {
		requireElement(elementSet, elementId);
		if (_inner !is null) {
			auto r = _inner.list(elementSet, elementId, actor);
			foreach (ref c; r) c.deletable = c.createdBy == actor || _mayDeleteAny(elementSet);
			return r;
		}
		auto r = _repo.forElement(elementSet, elementId).map!(c => toDto(c, true)).array;
		r.reverse(); // newest first: the current state on top
		return r;
	}

	CommentDto add(string elementSet, string elementId, string text, string actor) {
		requireElement(elementSet, elementId);
		if (_inner !is null) return _inner.add(elementSet, elementId, text, actor);
		auto c = new Comment;
		c.id = "cmt-" ~ randomUUID().toString()[0 .. 13];
		c.elementSet = elementSet;
		c.elementId = elementId;
		c.text = text;
		c.createdAt = Clock.currTime().toUTC().toISOExtString();
		c.createdBy = actor.length ? actor : "system";
		c.validate();
		_repo.save(c);
		if (_onAdded !is null) _onAdded(c);
		return toDto(c, true);
	}

	void remove(string commentId, string actor) {
		if (_inner !is null) {
			// look the comment up through the element (read access), then check author / delete right
			auto all = findInInner(commentId, actor);
			if (all.createdBy != actor && !_mayDeleteAny(all.elementSet))
				throw new AccessDeniedException(all.elementSet, "Only the author or a user who may delete " ~ all.elementSet ~ " can delete this comment");
			_inner.remove(commentId, actor);
			return;
		}
		if (_repo.find(commentId) is null) throw new EntityNotFoundException("Comments", commentId);
		_repo.remove(commentId);
	}

	size_t count(string elementSet, string elementId) {
		requireElement(elementSet, elementId);
		return _inner !is null ? _inner.count(elementSet, elementId) : _repo.forElement(elementSet, elementId).length;
	}

	/// Unrestricted only: the comment with its element (for the checked remove).
	CommentDto find(string commentId) {
		auto c = _repo.find(commentId);
		if (c is null) throw new EntityNotFoundException("Comments", commentId);
		return toDto(c, true);
	}

	private CommentDto findInInner(string commentId, string actor) {
		auto inner = cast(CommentsInteractor) _inner;
		auto c = inner.find(commentId);
		requireElement(c.elementSet, c.elementId); // read access to the element
		return c;
	}

	/// The element must exist (and, for callers, be readable).
	private void requireElement(string elementSet, string elementId) {
		static foreach (S; EamDtoSets)
			if (S.setName == elementSet) { manage!S(_uc).get(elementId); return; }
		throw new ValidationException("elementSet", "Unknown entity set '" ~ elementSet ~ "'");
	}

	private static CommentDto toDto(Comment c, bool deletable) {
		return CommentDto(c.id, c.elementSet, c.elementId, c.text, c.createdAt, c.createdBy, deletable);
	}
}
