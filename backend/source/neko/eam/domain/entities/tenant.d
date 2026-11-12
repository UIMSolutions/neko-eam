/// Tenant (Mandant) - an isolated architecture repository with its own data, users, roles and permissions.
/// Tenants are managed on platform level (not inside a tenant's repository).
module neko.eam.domain.entities.tenant;

import std.ascii : isDigit, isLower;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;

/// Id of the tenant that uses the classic single data file; it always exists.
enum defaultTenantId = "default";

final class Tenant {
	string id;                        /// short key, e.g. "acme" (also the file name of its data)
	string name;                      /// display name
	string description;
	TenantStatus status = TenantStatus.Active;
	string zoneId;                    /// XSUAA identity zone (subaccount) mapped to this tenant
	string createdAt, createdBy, modifiedAt, modifiedBy;

	void validate() const {
		if (!isValidTenantId(id))
			throw new ValidationException("id", "Tenant id '" ~ id ~ "': 2-31 characters, lower case letters, digits and '-', starting with a letter");
		if (name.length == 0)
			throw new ValidationException("name", "A tenant needs a name");
		if (id == defaultTenantId && status != TenantStatus.Active)
			throw new ValidationException("status", "The default tenant cannot be suspended");
	}
}

/// Tenant ids are used in file names and URLs - only a safe subset is allowed.
bool isValidTenantId(string id) pure @safe {
	if (id.length < 2 || id.length > 31 || !isLower(id[0])) return false;
	foreach (char c; id) if (!(isLower(c) || isDigit(c) || c == '-')) return false;
	return true;
}

unittest {
	assert(isValidTenantId("acme") && isValidTenantId("acme-2") && isValidTenantId(defaultTenantId));
	assert(!isValidTenantId("A") && !isValidTenantId("../x") && !isValidTenantId("1abc") && !isValidTenantId("a b"));
	auto t = new Tenant;
	t.id = "acme";
	bool failed;
	try t.validate(); catch (ValidationException e) failed = e.field == "name";
	assert(failed);
	t.name = "ACME";
	t.validate();
}
