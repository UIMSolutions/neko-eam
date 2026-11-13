/// Notifications: changes of elements by one user that concern other users (activity), and the read /
/// dismissed state of each user's notifications. Alerts (due and overdue items) are computed from the data.
module neko.eam.domain.entities.activity;

/// Longest comment excerpt kept in an activity.
enum maxActivityTextLength = 280;

/// A change of an element that is shown to the users concerned (its creator, last editor, commenters).
final class Activity {
	string id;
	string type;         /// Updated | Deleted | Commented
	string elementSet;   /// entity set of the element
	string elementId;
	string elementName;
	string actor;        /// user who made the change
	string at;           /// ISO timestamp (UTC)
	string text;         /// comment excerpt (Commented)
	string[] fields;     /// changed fields (Updated)
	string[] audience;   /// user keys (see `userKey`) to notify; the actor never sees own changes
}

/// Read and dismissed notifications of one user (ids of alerts and activities).
final class NotificationState {
	string user;         /// user key
	string[] read;
	string[] dismissed;
}

/// Key of a user in activities and notification states: lower-case user name, without the channel suffix
/// of CLI / desktop changes (`anna@cli` -> `anna`). Technical actors yield "".
string userKey(string actor) pure @safe {
	import std.algorithm : endsWith;
	import std.string : toLower;
	auto k = actor.toLower;
	foreach (suffix; ["@cli", "@gui"]) if (k.endsWith(suffix)) k = k[0 .. $ - suffix.length];
	if (k == "system" || k == "scheduler" || k == "anonymous") return "";
	return k;
}

unittest {
	assert(userKey("Anna") == "anna" && userKey("anna@cli") == "anna" && userKey("system") == "" && userKey("") == "");
}
