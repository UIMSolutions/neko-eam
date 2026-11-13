/// Persistent document store: one JSON file, replaced atomically.
///
/// Every change used to rewrite the whole file at once, which blocks the server for the time it takes to
/// serialise the complete repository. With a `writeDelay`, changes made inside the vibe.d event loop are
/// coalesced instead: the file is written once, `writeDelay` after the first unsaved change (all changes of
/// that window in one write). Outside of the event loop (CLI, desktop GUI, tests) and for `replaceAll`
/// (restore) the file is still written immediately. `flushAll` writes pending changes on shutdown.
module neko.eam.persistence.storages.jsonfilestorage;

import core.time : Duration;
import std.algorithm : countUntil, remove;
import std.file : exists, readText, write, rename, mkdirRecurse;
import std.path : dirName;
import vibe.data.json;
import neko.eam.persistence.storages.memorystorage;

class JsonFileStorage : MemoryStorage {
	private {
		string _path;
		Duration _delay;
		bool _dirty;     // changes not yet written
		bool _scheduled; // a delayed write is pending
		bool _discarded; // the tenant was deleted - never write again
	}
	private static JsonFileStorage[] s_delayed; // storages with delayed writes (of this thread)

	this(string path, Duration writeDelay = Duration.zero) {
		_path = path;
		_delay = writeDelay;
		if (exists(path)) {
			auto root = parseJsonString(readText(path));
			foreach (string key, value; root["collections"]) {
				Json[] docs;
				foreach (d; value) docs ~= d;
				_data[key] = docs;
			}
		}
		if (_delay > Duration.zero) s_delayed ~= this;
	}

	override void store(string collection, Json[] documents) {
		super.store(collection, documents);
		changed();
	}

	override string location() { return _path; }

	/// Written with a single atomic rename - a crash leaves either the old or the new state.
	override void replaceAll(Json[][string] collections) {
		super.replaceAll(collections);
		flush();
	}

	/// True while changes wait for the delayed write.
	bool dirty() const { return _dirty; }

	/// Writes the whole repository to a temporary file and renames it (atomic on POSIX).
	void flush() {
		if (_discarded) return;
		_dirty = false;
		scope (failure) _dirty = true; // retried with the next change / on shutdown
		auto cols = Json.emptyObject;
		foreach (k, docs; _data) cols[k] = Json(docs);
		auto root = Json(["format": Json("neko-eam"), "version": Json(1), "collections": cols]);
		if (_path.dirName.length) mkdirRecurse(_path.dirName);
		auto tmp = _path ~ ".tmp";
		write(tmp, root.toPrettyString());
		rename(tmp, _path);
	}

	/// The data file is about to be removed: pending and future changes are not written any more.
	void discard() {
		_discarded = true;
		_dirty = false;
		auto i = s_delayed.countUntil!(s => s is this);
		if (i >= 0) s_delayed = s_delayed.remove(i);
	}

	/// Writes the pending changes of all storages with delayed writes (call on shutdown).
	static void flushAll() {
		foreach (s; s_delayed) if (s._dirty) s.flush();
	}

	private void changed() {
		import vibe.core.core : setTimer;
		import vibe.core.task : Task;
		if (_discarded) return;
		if (_delay <= Duration.zero || Task.getThis() == Task.init) return flush();
		_dirty = true;
		if (_scheduled) return;
		_scheduled = true;
		setTimer(_delay, () nothrow {
			_scheduled = false;
			if (!_dirty) return;
			try flush();
			catch (Exception e) {
				import vibe.core.log : logError;
				try logError("Writing %s failed (retried with the next change): %s", _path, e.msg);
				catch (Exception) {}
			}
		});
	}
}

unittest {
	import core.time : msecs;
	import std.file : remove, tempDir;
	import std.path : buildPath;
	import std.uuid : randomUUID;
	auto path = buildPath(tempDir, "neko-eam-test-" ~ randomUUID().toString ~ ".json");
	scope (exit) if (exists(path)) remove(path);
	// outside of the event loop every change is written at once, even with a delay
	auto s = new JsonFileStorage(path, 200.msecs);
	s.store("Things", [Json(["id": Json("a")])]);
	assert(!s.dirty && new JsonFileStorage(path).load("Things").length == 1);
	s.discard();
	s.store("Things", []);
	assert(new JsonFileStorage(path).load("Things").length == 1, "a discarded storage is not written");
}
