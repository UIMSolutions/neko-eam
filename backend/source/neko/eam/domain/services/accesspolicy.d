/// Authorization: effective rights of a user from the permissions of the user's active roles.
module neko.eam.domain.services.accesspolicy;

import std.algorithm : canFind, sort;
import std.array : join;
import std.conv : to;
import neko.eam.domain.entities;
import neko.eam.domain.enumerations;

/// Read / create / update / delete on one entity set.
struct SetRights {
	bool read, create, update, remove;

	bool allows(AccessAction a) const pure @safe {
		final switch (a) {
			case AccessAction.Read: return read;
			case AccessAction.Create: return create;
			case AccessAction.Update: return update;
			case AccessAction.Delete: return remove;
		}
	}

	void grant(const Permission p) pure @safe {
		read |= p.canRead; create |= p.canCreate; update |= p.canUpdate; remove |= p.canDelete;
	}

	bool any() const pure @safe { return read || create || update || remove; }

	/// "RCUD" style short form, "-" for no rights.
	string code() const pure @safe {
		string s = (read ? "R" : "") ~ (create ? "C" : "") ~ (update ? "U" : "") ~ (remove ? "D" : "");
		return s.length ? s : "-";
	}
}

/// Sets that are not covered by `All` and need an explicit permission.
immutable string[] accessManagementSets = ["Users", "Roles", "Permissions"];

bool isAccessManagementSet(string setName) pure @safe { return accessManagementSets.canFind(setName); }

/// Rights of one user. `unrestricted` bypasses all checks (administrators, bootstrap).
struct EffectiveRights {
	bool unrestricted;
	SetRights allSets;                /// granted via `All` (not for access management sets)
	SetRights[string] perSet;

	bool can(string setName, AccessAction action) const pure @safe {
		if (unrestricted) return true;
		if (auto r = setName in perSet) if (r.allows(action)) return true;
		return !isAccessManagementSet(setName) && allSets.allows(action);
	}

	/// Administrator of the repository: unrestricted, or full rights on all sets incl. access management
	/// (required for backup and restore of a tenant).
	bool isAdministrator() const pure @safe {
		if (unrestricted) return true;
		bool full(SetRights r) { return r.read && r.create && r.update && r.remove; }
		if (!full(allSets)) return false;
		foreach (s; accessManagementSets) if (!full(rightsOn(s))) return false;
		return true;
	}

	SetRights rightsOn(string setName) const pure @safe {
		return SetRights(can(setName, AccessAction.Read), can(setName, AccessAction.Create),
			can(setName, AccessAction.Update), can(setName, AccessAction.Delete));
	}

	/// Union of the permissions of the active roles of an enabled user.
	static EffectiveRights resolve(const User user, Role[] roles, Permission[] permissions, string today) {
		EffectiveRights r;
		if (user is null || !user.isEnabled(today)) return r;
		Permission[string] byId;
		foreach (p; permissions) byId[p.id] = p;
		foreach (role; roles) {
			if (!user.roleIds.canFind(role.id) || role.status != ObjectState.Active) continue;
			foreach (pid; role.permissionIds) {
				auto p = pid in byId;
				if (p is null) continue;
				if (p.entitySet == EntitySetName.All) r.allSets.grant(*p);
				else {
					auto name = (*p).entitySet.to!string;
					auto cur = r.perSet.get(name, SetRights.init);
					cur.grant(*p);
					r.perSet[name] = cur;
				}
			}
		}
		return r;
	}

	/// Human readable summary, e.g. "All: R; Applications: RCUD".
	string summary() const {
		if (unrestricted) return "Unrestricted";
		string[] parts;
		if (allSets.any) parts ~= "All: " ~ allSets.code;
		auto names = perSet.keys;
		names.sort();
		foreach (n; names) if (perSet[n].any) parts ~= n ~ ": " ~ perSet[n].code;
		return parts.length ? parts.join("; ") : "No access";
	}
}

unittest {
	auto read = new Permission; read.id = "p-read"; read.entitySet = EntitySetName.All;
	auto apps = new Permission; apps.id = "p-apps"; apps.entitySet = EntitySetName.Applications;
	apps.canCreate = apps.canUpdate = apps.canDelete = true;
	auto users = new Permission; users.id = "p-users"; users.entitySet = EntitySetName.Users;
	auto viewer = new Role; viewer.id = "r-view"; viewer.permissionIds = ["p-read"];
	auto owner = new Role; owner.id = "r-own"; owner.permissionIds = ["p-apps"];
	auto locked = new Role; locked.id = "r-users"; locked.permissionIds = ["p-users"]; locked.status = ObjectState.Inactive;
	auto u = new User; u.userName = "anna"; u.roleIds = ["r-view", "r-own", "r-users"];
	auto r = EffectiveRights.resolve(u, [viewer, owner, locked], [read, apps, users], "2026-11-12");
	assert(r.can("Products", AccessAction.Read) && !r.can("Products", AccessAction.Update));
	assert(r.can("Applications", AccessAction.Delete));
	assert(!r.can("Users", AccessAction.Read), "All does not cover access management, inactive roles grant nothing");
	assert(r.summary == "All: R; Applications: RCUD");
	u.active = false;
	assert(!EffectiveRights.resolve(u, [viewer], [read], "2026-11-12").can("Products", AccessAction.Read));
	assert(EffectiveRights(true).can("Users", AccessAction.Delete));
	assert(!r.isAdministrator && EffectiveRights(true).isAdministrator);
}
