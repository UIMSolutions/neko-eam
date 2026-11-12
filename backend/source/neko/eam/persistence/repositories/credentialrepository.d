/// Passwords (hashes) of the users of a tenant, stored in the tenant's document storage
/// (collection "Credentials") - part of every backup, never part of the OData model or the workbook export.
module neko.eam.persistence.repositories.credentialrepository;

import std.algorithm : countUntil, remove;
import vibe.data.json;
import neko.eam.domain.entities.credential;
import neko.eam.ports.repositories : ICredentialRepository;
import neko.eam.ports.storages : IDocumentStorage;

class CredentialRepository : ICredentialRepository {
	enum collection = "Credentials";
	private IDocumentStorage _storage;
	private Credential[] _all; // cached; written through on every change

	this(IDocumentStorage storage) {
		_storage = storage;
		foreach (d; storage.load(collection)) {
			auto c = fromJson(d);
			if (c.userId.length && c.passwordHash.length) _all ~= c;
		}
	}

	Credential find(string userId) {
		foreach (c; _all) if (c.userId == userId) return c;
		return null;
	}

	void save(Credential credential) {
		auto i = _all.countUntil!(c => c.userId == credential.userId);
		if (i >= 0) _all[i] = credential;
		else _all ~= credential;
		flush();
	}

	void remove(string userId) {
		auto i = _all.countUntil!(c => c.userId == userId);
		if (i < 0) return;
		_all = _all.remove(i);
		flush();
	}

	size_t count() { return _all.length; }

	private void flush() {
		Json[] docs;
		foreach (c; _all) docs ~= toJson(c);
		_storage.store(collection, docs);
	}

	private static Json toJson(Credential c) {
		auto j = Json.emptyObject;
		j["schemaVersion"] = 1;
		static foreach (f; ["userId", "passwordHash", "changedAt", "changedBy"]) j[f] = __traits(getMember, c, f);
		j["mustChange"] = c.mustChange;
		return j;
	}

	private static Credential fromJson(Json j) {
		auto c = new Credential;
		static foreach (f; ["userId", "passwordHash", "changedAt", "changedBy"]) __traits(getMember, c, f) = j[f].opt!string("");
		c.mustChange = j["mustChange"].opt!bool(false);
		return c;
	}
}

unittest {
	import neko.eam.persistence.storages.memorystorage : MemoryStorage;
	auto storage = new MemoryStorage;
	auto repo = new CredentialRepository(storage);
	auto c = new Credential;
	c.userId = "usr-1";
	c.passwordHash = "x$1$a$b";
	repo.save(c);
	c.mustChange = true;
	repo.save(c);
	assert(repo.count == 1);
	auto reloaded = new CredentialRepository(storage);
	assert(reloaded.find("usr-1").mustChange && reloaded.find("usr-2") is null);
	reloaded.remove("usr-1");
	assert(new CredentialRepository(storage).count == 0);
}
