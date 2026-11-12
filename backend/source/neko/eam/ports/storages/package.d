/// Driven ports for low-level document stores.
module neko.eam.ports.storages;

public import vibe.data.json : Json;

/// A store of JSON documents grouped by collection.
interface IDocumentStorage {
	Json[] load(string collection);
	void store(string collection, Json[] documents);
	string[] collections();
	/// Storage location description (file path, "memory", ...).
	string location();
	/// Replaces the whole content in one step (restore); collections not given are removed.
	void replaceAll(Json[][string] collections);
}

/// Driven port: opens the document storage of a tenant (one data file per tenant).
interface ITenantStorageProvider {
	IDocumentStorage open(string tenantId);
	/// Removes the tenant's data (after a final backup).
	void destroy(string tenantId);
	string location(string tenantId);
}
