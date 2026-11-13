/// REST interface of the notifications of the signed-in user (Fiori shell bar, Android app):
///
///   GET  /api/v1/notifications           {unread, items}: alerts first, then activities (newest first)
///   POST /api/v1/notifications/read      {ids: [...]} or {all: true}  -> updated list
///   POST /api/v1/notifications/dismiss   {ids: [...]} or {all: true}  -> updated list
module neko.eam.presentation.rest.notifications;

import vibe.http.common : HTTPMethod;
import vibe.web.rest;
import neko.eam.domain.exceptions : ValidationException;
import neko.eam.ports.usecases;
import neko.eam.presentation.http.access : currentSubject;

/// Most ids accepted in one request.
enum maxIdsPerRequest = 1000;

@path("/api/v1")
interface INotificationsApi {
@safe:
	@method(HTTPMethod.GET) @path("/notifications")
	NotificationListDto getNotifications();

	/// Marks the notifications `ids` (or `all`) as read.
	@method(HTTPMethod.POST) @path("/notifications/read")
	NotificationListDto markRead(string[] ids = null, bool all = false);

	/// Removes the notifications `ids` (or `all`) from the user's list.
	@method(HTTPMethod.POST) @path("/notifications/dismiss")
	NotificationListDto dismiss(string[] ids = null, bool all = false);
}

/// Every method works for the caller of the request only.
class NotificationsApi : INotificationsApi {
	private IEamUseCases _uc;

	this(IEamUseCases uc) { _uc = uc; }

	NotificationListDto getNotifications() @trusted { return _uc.notifications.forUser(currentSubject()); }

	NotificationListDto markRead(string[] ids = null, bool all = false) @trusted {
		checkSelection(ids, all);
		return _uc.notifications.markRead(currentSubject(), ids, all);
	}

	NotificationListDto dismiss(string[] ids = null, bool all = false) @trusted {
		checkSelection(ids, all);
		return _uc.notifications.dismiss(currentSubject(), ids, all);
	}
}

private void checkSelection(string[] ids, bool all) @safe {
	if (ids.length > maxIdsPerRequest) throw new ValidationException("ids", "Too many ids in one request");
	if (!all && !ids.length) throw new ValidationException("ids", "No notifications given");
}

unittest {
	import std.exception : assertThrown, assertNotThrown;
	assertThrown!ValidationException(checkSelection(null, false));
	assertThrown!ValidationException(checkSelection(new string[maxIdsPerRequest + 1], false));
	assertNotThrown(checkSelection(null, true));
	assertNotThrown(checkSelection(["a"], false));
}
