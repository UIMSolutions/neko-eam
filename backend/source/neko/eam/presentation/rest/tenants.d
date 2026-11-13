/// REST interface of the tenants (Mandanten) - system administrators only:
///
///   GET    /api/v1/tenants          all tenants
///   POST   /api/v1/tenants          create  {tenant: {id, name, ...}, seedDemoData, adminUserName, adminEmail}
///                                   (the tenant fields may also be sent at the top level) -> 201
///   PATCH  /api/v1/tenants/{id}     change name, description, status, zoneId (fields that are sent)
///   DELETE /api/v1/tenants/{id}     final backup, then remove the tenant and its data
module neko.eam.presentation.rest.tenants;

import vibe.data.json : Json;
import vibe.http.common : HTTPMethod;
import vibe.web.rest;
import neko.eam.ports.usecases;
import neko.eam.presentation.http.access : currentSubject;
import neko.eam.presentation.rest.support : created;

@path("/api/v1")
interface ITenantsApi {
@safe:
	@method(HTTPMethod.GET) @path("/tenants")
	TenantDto[] getTenants();

	@method(HTTPMethod.POST) @path("/tenants") @bodyParam("request") @after!(created!TenantDto)()
	TenantDto createTenant(Json request);

	@method(HTTPMethod.PATCH) @path("/tenants/:id") @bodyParam("changes")
	TenantDto updateTenant(string _id, Json changes);

	@method(HTTPMethod.DELETE) @path("/tenants/:id")
	void deleteTenant(string _id);
}

class TenantsApi : ITenantsApi {
	private IEamPlatform _platform;

	this(IEamPlatform platform) { _platform = platform; }

	TenantDto[] getTenants() @trusted { return _platform.listTenants(currentSubject()); }

	TenantDto createTenant(Json request) @trusted {
		return _platform.createTenant(toCreateRequest(request), currentSubject());
	}

	TenantDto updateTenant(string _id, Json changes) @trusted {
		auto subject = currentSubject();
		auto tenant = _platform.getTenant(_id, subject);
		applyChanges(tenant, changes);
		return _platform.updateTenant(_id, tenant, subject);
	}

	void deleteTenant(string _id) @trusted { _platform.deleteTenant(_id, currentSubject()); }
}

/// Create request from `{tenant: {...}, ...}` or a flat `{id, name, ..., seedDemoData, ...}`.
TenantCreateDto toCreateRequest(Json body) {
	TenantCreateDto request;
	auto t = body["tenant"].type == Json.Type.object ? body["tenant"] : body;
	static foreach (f; ["id", "name", "description", "status", "zoneId"])
		__traits(getMember, request.tenant, f) = t[f].opt!string(__traits(getMember, request.tenant, f));
	request.seedDemoData = body["seedDemoData"].opt!bool(false);
	request.adminUserName = body["adminUserName"].opt!string("");
	request.adminEmail = body["adminEmail"].opt!string("");
	return request;
}

/// PATCH semantics: only the string fields that are sent change.
void applyChanges(ref TenantDto tenant, Json changes) {
	static foreach (f; ["name", "description", "status", "zoneId"])
		if (changes[f].type == Json.Type.string) __traits(getMember, tenant, f) = changes[f].get!string;
}

unittest {
	import vibe.data.json : parseJsonString;
	auto nested = toCreateRequest(parseJsonString(`{"tenant": {"id": "acme", "name": "ACME"}, "seedDemoData": true}`));
	assert(nested.tenant.id == "acme" && nested.tenant.name == "ACME" && nested.seedDemoData);
	auto flat = toCreateRequest(parseJsonString(`{"id": "b", "name": "B", "adminUserName": "boss"}`));
	assert(flat.tenant.id == "b" && flat.adminUserName == "boss" && !flat.seedDemoData);

	TenantDto t;
	t.name = "Old";
	t.description = "keep";
	applyChanges(t, parseJsonString(`{"name": "New", "description": null}`));
	assert(t.name == "New" && t.description == "keep");
}
