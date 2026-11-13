/// REST interface of the running comments (journal) of any element:
///
///   GET    /api/v1/comments/{set}/{id}       comments of an element, newest first
///   POST   /api/v1/comments/{set}/{id}       add  {text}  -> 201 with the comment
///   DELETE /api/v1/comments/{commentId}      author, or delete permission on the element's set
module neko.eam.presentation.rest.comments;

import vibe.http.common : HTTPMethod;
import vibe.web.rest;
import neko.eam.ports.usecases;
import neko.eam.presentation.http.access : callerUseCases, currentSubject;
import neko.eam.presentation.rest.support : created;

@path("/api/v1")
interface ICommentsApi {
@safe:
	@method(HTTPMethod.GET) @path("/comments/:set/:id")
	CommentDto[] getComments(string _set, string _id);

	@method(HTTPMethod.POST) @path("/comments/:set/:id") @after!(created!CommentDto)()
	CommentDto addComment(string _set, string _id, string text = "");

	@method(HTTPMethod.DELETE) @path("/comments/:commentId")
	void removeComment(string _commentId);
}

class CommentsApi : ICommentsApi {
	private IEamUseCases _uc;

	this(IEamUseCases uc) { _uc = uc; }

	CommentDto[] getComments(string _set, string _id) @trusted {
		return callerUseCases(_uc).comments.list(_set, _id, currentSubject().userName);
	}

	CommentDto addComment(string _set, string _id, string text = "") @trusted {
		auto c = callerUseCases(_uc).comments.add(_set, _id, text, currentSubject().userName);
		c.deletable = true; // the author may delete the own comment
		return c;
	}

	void removeComment(string _commentId) @trusted {
		callerUseCases(_uc).comments.remove(_commentId, currentSubject().userName);
	}
}
