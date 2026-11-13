/// Activity journal (collection "Activities") and notification states (collection "NotificationStates")
/// stored in the tenant's document storage - part of every backup, never part of the OData model.
module neko.eam.persistence.repositories.activityrepository;

import core.time : days;
import std.datetime : Clock, SysTime;
import vibe.data.json;
import neko.eam.domain.entities.activity;
import neko.eam.ports.repositories : IActivityRepository, INotificationStateRepository;
import neko.eam.ports.storages : IDocumentStorage;

/// Bounded journal: the newest `maxEntries` activities of the last `maxAgeDays` days.
class ActivityRepository : IActivityRepository {
	enum collection = "Activities";
	enum maxEntries = 5000;
	enum maxAgeDays = 90;
	private {
		IDocumentStorage _storage;
		Activity[] _all;   // oldest first
		Json[] _docs;      // JSON form of `_all` (same order): appending converts only the new entry
	}

	this(IDocumentStorage storage) {
		_storage = storage;
		foreach (d; storage.load(collection)) {
			auto a = fromJson(d);
			if (a.id.length) { _all ~= a; _docs ~= toJson(a); }
		}
	}

	void add(Activity activity) {
		_all ~= activity;
		_docs ~= toJson(activity);
		prune(Clock.currTime);
		_storage.store(collection, _docs);
	}

	Activity[] all() { return _all; }
	size_t count() { return _all.length; }

	private void prune(SysTime now) {
		auto limit = (now - maxAgeDays.days).toUTC().toISOExtString();
		size_t drop = _all.length > maxEntries ? _all.length - maxEntries : 0;
		while (drop < _all.length && _all[drop].at < limit) drop++;
		if (drop) { _all = _all[drop .. $].dup; _docs = _docs[drop .. $].dup; }
	}

	private static Json toJson(Activity a) {
		auto j = Json.emptyObject;
		j["schemaVersion"] = 1;
		static foreach (f; ["id", "type", "elementSet", "elementId", "elementName", "actor", "at", "text"])
			j[f] = __traits(getMember, a, f);
		j["fields"] = strings(a.fields);
		j["audience"] = strings(a.audience);
		return j;
	}

	private static Activity fromJson(Json j) {
		auto a = new Activity;
		static foreach (f; ["id", "type", "elementSet", "elementId", "elementName", "actor", "at", "text"])
			__traits(getMember, a, f) = j[f].opt!string("");
		a.fields = strings(j["fields"]);
		a.audience = strings(j["audience"]);
		return a;
	}
}

class NotificationStateRepository : INotificationStateRepository {
	enum collection = "NotificationStates";
	private {
		IDocumentStorage _storage;
		NotificationState[string] _byUser;
		Json[string] _docs;
	}

	this(IDocumentStorage storage) {
		_storage = storage;
		foreach (d; storage.load(collection)) {
			auto s = new NotificationState;
			s.user = d["user"].opt!string("");
			s.read = strings(d["read"]);
			s.dismissed = strings(d["dismissed"]);
			if (s.user.length) { _byUser[s.user] = s; _docs[s.user] = toJson(s); }
		}
	}

	NotificationState find(string user) {
		if (auto s = user in _byUser) {
			auto c = new NotificationState; // copy: the caller changes it before saving
			c.user = s.user; c.read = s.read.dup; c.dismissed = s.dismissed.dup;
			return c;
		}
		return null;
	}

	void save(NotificationState state) {
		_byUser[state.user] = state;
		_docs[state.user] = toJson(state);
		_storage.store(collection, _docs.values);
	}

	private static Json toJson(NotificationState s) {
		auto j = Json.emptyObject;
		j["schemaVersion"] = 1;
		j["user"] = s.user;
		j["read"] = strings(s.read);
		j["dismissed"] = strings(s.dismissed);
		return j;
	}
}

private Json strings(const string[] values) {
	auto arr = Json.emptyArray;
	foreach (v; values) arr ~= Json(v);
	return arr;
}

private string[] strings(Json j) {
	string[] r;
	if (j.type == Json.Type.array) foreach (e; j) if (e.type == Json.Type.string) r ~= e.get!string;
	return r;
}

unittest {
	import neko.eam.persistence.storages.memorystorage : MemoryStorage;
	auto storage = new MemoryStorage;
	auto repo = new ActivityRepository(storage);
	auto now = Clock.currTime().toUTC().toISOExtString();
	auto old = new Activity; // activities are appended in time order: the oldest is first
	old.id = "act-old"; old.at = "2000-01-01T00:00:00Z";
	repo.add(old);
	foreach (i; 0 .. 3) {
		auto a = new Activity;
		a.id = "act-" ~ cast(char)('a' + i); a.type = "Updated"; a.at = now; a.audience = ["anna"]; a.fields = ["status"];
		repo.add(a);
	}
	assert(repo.count == 3, "activities older than the retention are dropped");
	auto reloaded = new ActivityRepository(storage);
	assert(reloaded.count == 3 && reloaded.all[0].audience == ["anna"] && reloaded.all[2].fields == ["status"]);

	auto states = new NotificationStateRepository(storage);
	assert(states.find("anna") is null);
	auto s = new NotificationState;
	s.user = "anna"; s.read = ["x"];
	states.save(s);
	auto copy = new NotificationStateRepository(storage).find("anna");
	copy.read ~= "y";
	assert(new NotificationStateRepository(storage).find("anna").read == ["x"]);
}
