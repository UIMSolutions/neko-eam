/// One JSON data file per tenant. The default tenant keeps the configured data file (compatibility).
module neko.eam.persistence.storages.tenantstorage;

import core.time : Duration;
import std.file : exists, remove;
import std.path : buildPath;
import neko.eam.domain.entities.tenant : defaultTenantId, isValidTenantId;
import neko.eam.ports.storages;
import neko.eam.persistence.storages.jsonfilestorage;
import neko.eam.persistence.storages.memorystorage;

class FileTenantStorageProvider : ITenantStorageProvider {
	private string _defaultFile, _directory;
	private Duration _writeDelay;
	private JsonFileStorage[string] _opened;

	/// `writeDelay`: changes made in the server are written at most this long after they happened
	/// (coalesced into one write); zero writes every change at once.
	this(string defaultDataFile, string tenantDirectory, Duration writeDelay = Duration.zero) {
		_defaultFile = defaultDataFile; _directory = tenantDirectory; _writeDelay = writeDelay;
	}

	IDocumentStorage open(string tenantId) {
		if (auto old = tenantId in _opened) { // reopened: write what is pending, then only the new one writes
			if (old.dirty) old.flush();
			old.discard();
		}
		auto s = new JsonFileStorage(location(tenantId), _writeDelay);
		return _opened[tenantId] = s;
	}

	void destroy(string tenantId) {
		if (tenantId == defaultTenantId) throw new Exception("The default tenant cannot be removed");
		if (auto s = tenantId in _opened) { s.discard(); _opened.remove(tenantId); }
		auto p = location(tenantId);
		if (exists(p)) remove(p);
	}

	string location(string tenantId) {
		if (tenantId == defaultTenantId) return _defaultFile;
		if (!isValidTenantId(tenantId)) throw new Exception("Invalid tenant id");
		return buildPath(_directory, tenantId ~ ".json");
	}
}

/// Volatile tenants (tests).
class MemoryTenantStorageProvider : ITenantStorageProvider {
	private MemoryStorage[string] _stores;

	IDocumentStorage open(string tenantId) {
		if (auto s = tenantId in _stores) return *s;
		return _stores[tenantId] = new MemoryStorage;
	}

	void destroy(string tenantId) { _stores.remove(tenantId); }
	string location(string tenantId) { return "memory:" ~ tenantId; }
}
