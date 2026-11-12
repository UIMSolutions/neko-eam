/// One JSON data file per tenant. The default tenant keeps the configured data file (compatibility).
module neko.eam.persistence.storages.tenantstorage;

import std.file : exists, remove;
import std.path : buildPath;
import neko.eam.domain.entities.tenant : defaultTenantId, isValidTenantId;
import neko.eam.ports.storages;
import neko.eam.persistence.storages.jsonfilestorage;
import neko.eam.persistence.storages.memorystorage;

class FileTenantStorageProvider : ITenantStorageProvider {
	private string _defaultFile, _directory;

	this(string defaultDataFile, string tenantDirectory) { _defaultFile = defaultDataFile; _directory = tenantDirectory; }

	IDocumentStorage open(string tenantId) { return new JsonFileStorage(location(tenantId)); }

	void destroy(string tenantId) {
		if (tenantId == defaultTenantId) throw new Exception("The default tenant cannot be removed");
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
