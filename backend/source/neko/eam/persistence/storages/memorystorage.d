/// Volatile in-memory document store (tests, demo mode).
module neko.eam.persistence.storages.memorystorage;

import neko.eam.ports.storages;

class MemoryStorage : IDocumentStorage {
	protected Json[][string] _data;

	Json[] load(string collection) {
		if (auto p = collection in _data) return (*p).dup;
		return [];
	}

	void store(string collection, Json[] documents) {
		_data[collection] = documents.dup;
	}

	string[] collections() { return _data.keys; }

	string location() { return "memory"; }

	void replaceAll(Json[][string] collections) {
		Json[][string] copy;
		foreach (k, docs; collections) copy[k] = docs.dup;
		_data = copy;
	}
}
