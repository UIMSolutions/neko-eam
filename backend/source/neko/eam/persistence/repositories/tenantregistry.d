/// Tenant registry stored in its own document storage (data/tenants.json), outside of every tenant.
module neko.eam.persistence.repositories.tenantregistry;

import std.conv : to;
import vibe.data.json;
import neko.eam.domain.entities.tenant;
import neko.eam.domain.enumerations : TenantStatus;
import neko.eam.ports.repositories : ITenantRegistry;
import neko.eam.ports.storages : IDocumentStorage;

class TenantRegistry : ITenantRegistry {
	private IDocumentStorage _storage;
	private Tenant[] _cache; // parsed tenants - every request resolves its tenant
	private bool _cached;
	enum collection = "Tenants";

	this(IDocumentStorage storage) { _storage = storage; }

	/// Copies (callers may modify them before saving).
	Tenant[] all() {
		Tenant[] r;
		foreach (t; cached) r ~= copy(t);
		return r;
	}

	Tenant find(string id) {
		foreach (t; cached) if (t.id == id) return copy(t);
		return null;
	}

	void save(Tenant t) {
		Json[] docs;
		bool replaced;
		foreach (d; _storage.load(collection)) {
			if (d["id"].opt!string("") == t.id) { docs ~= toJson(t); replaced = true; }
			else docs ~= d;
		}
		if (!replaced) docs ~= toJson(t);
		_storage.store(collection, docs);
		_cached = false;
	}

	void remove(string id) {
		Json[] docs;
		foreach (d; _storage.load(collection)) if (d["id"].opt!string("") != id) docs ~= d;
		_storage.store(collection, docs);
		_cached = false;
	}

	private Tenant[] cached() {
		if (!_cached) {
			Tenant[] r;
			foreach (d; _storage.load(collection)) r ~= fromJson(d);
			_cache = r;
			_cached = true;
		}
		return _cache;
	}

	private static Tenant copy(Tenant t) {
		auto c = new Tenant;
		static foreach (f; ["id", "name", "description", "zoneId", "createdAt", "createdBy", "modifiedAt", "modifiedBy", "status"])
			__traits(getMember, c, f) = __traits(getMember, t, f);
		return c;
	}

	private static Json toJson(Tenant t) {
		auto j = Json.emptyObject;
		static foreach (f; ["id", "name", "description", "zoneId", "createdAt", "createdBy", "modifiedAt", "modifiedBy"])
			j[f] = __traits(getMember, t, f);
		j["status"] = t.status.to!string;
		return j;
	}

	private static Tenant fromJson(Json j) {
		auto t = new Tenant;
		static foreach (f; ["id", "name", "description", "zoneId", "createdAt", "createdBy", "modifiedAt", "modifiedBy"])
			__traits(getMember, t, f) = j[f].opt!string("");
		try t.status = j["status"].opt!string("Active").to!TenantStatus;
		catch (Exception) t.status = TenantStatus.Active;
		return t;
	}
}
