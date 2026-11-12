/// Persistent document store: one JSON file, written atomically on every change.
module neko.eam.persistence.storages.jsonfilestorage;

import std.file : exists, readText, write, rename, mkdirRecurse;
import std.path : dirName;
import vibe.data.json;
import neko.eam.persistence.storages.memorystorage;

class JsonFileStorage : MemoryStorage {
	private string _path;

	this(string path) {
		_path = path;
		if (exists(path)) {
			auto root = parseJsonString(readText(path));
			foreach (string key, value; root["collections"]) {
				Json[] docs;
				foreach (d; value) docs ~= d;
				_data[key] = docs;
			}
		}
	}

	override void store(string collection, Json[] documents) {
		super.store(collection, documents);
		flush();
	}

	override string location() { return _path; }

	/// Written with a single atomic rename - a crash leaves either the old or the new state.
	override void replaceAll(Json[][string] collections) {
		super.replaceAll(collections);
		flush();
	}

	/// Writes the whole repository to a temporary file and renames it (atomic on POSIX).
	void flush() {
		auto cols = Json.emptyObject;
		foreach (k, docs; _data) cols[k] = Json(docs);
		auto root = Json(["format": Json("neko-eam"), "version": Json(1), "collections": cols]);
		if (_path.dirName.length) mkdirRecurse(_path.dirName);
		auto tmp = _path ~ ".tmp";
		write(tmp, root.toPrettyString());
		rename(tmp, _path);
	}
}
