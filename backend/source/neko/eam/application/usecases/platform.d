/// Platform level: tenants (Mandanten), backup and restore.
///
/// Each tenant has its own document storage and its own use cases (incl. users, roles and permissions).
/// The platform opens them on demand, resolves the tenant of a caller, and takes / restores backups.
module neko.eam.application.usecases.platform;

import std.algorithm : canFind, filter, map, sort, startsWith;
import std.array : array;
import std.conv : to;
import std.datetime : Clock, SysTime;
import std.format : format;
import std.string : toLower;
import neko.eam.domain;
import neko.eam.application.dtos;
import neko.eam.application.services.backupcodec;
import neko.eam.ports.repositories;
import neko.eam.ports.storages;
import neko.eam.ports.usecases;

class EamPlatform : IEamPlatform {
	private {
		ITenantRegistry _registry;
		ITenantStorageProvider _storages;
		IBackupStore _backups;
		/// Builds the use cases of a tenant on its storage (composition root).
		IEamUseCases delegate(IDocumentStorage) _build;
		size_t _retention;
		struct Open { IDocumentStorage storage; IEamUseCases uc; }
		Open[string] _open;
	}

	/// `retention`: number of scheduled backups kept per tenant (manual ones are kept until deleted).
	this(ITenantRegistry registry, ITenantStorageProvider storages, IBackupStore backups,
			IEamUseCases delegate(IDocumentStorage) build, size_t retention) {
		_registry = registry; _storages = storages; _backups = backups; _build = build;
		_retention = retention;
		if (_registry.find(defaultTenantId) is null) {
			auto t = new Tenant;
			t.id = defaultTenantId;
			t.name = "Default";
			t.description = "Classic single repository (data file of the configuration)";
			t.createdAt = t.modifiedAt = now();
			t.createdBy = t.modifiedBy = "system";
			_registry.save(t);
		}
	}

	// ---------------------------------------------------------------- tenant resolution

	string resolveTenant(AccessSubjectDto subject, string requested) {
		Tenant t;
		bool byZone;
		if (subject.zoneId.length)
			foreach (c; _registry.all) if (c.zoneId.length && c.zoneId == subject.zoneId) { t = c; byZone = true; break; }
		if (t is null) {
			auto id = requested.length ? requested : defaultTenantId;
			t = _registry.find(id);
			if (t is null) throw new AccessDeniedException("", "Unknown tenant '" ~ id ~ "'");
		}
		if (t.status == TenantStatus.Suspended && !subject.systemAdministrator)
			throw new AccessDeniedException("", "Tenant '" ~ t.id ~ "' is suspended");
		if (!byZone && t.id != defaultTenantId && !subject.systemAdministrator
				&& !tenantUseCases(t.id).access.isKnownUser(subject))
			throw new AccessDeniedException("", "No access to tenant '" ~ t.id ~ "'");
		return t.id;
	}

	IEamUseCases tenantUseCases(string tenantId) {
		return open(tenantId).uc;
	}

	TenantRefDto[] tenantsFor(AccessSubjectDto subject) {
		TenantRefDto[] r;
		foreach (t; sortedTenants) {
			try {
				if (resolveTenant(subject, t.id) != t.id) continue;
				// the default tenant is always reachable, but only offered to its own users
				if (t.id == defaultTenantId && !subject.systemAdministrator && !subject.zoneId.length) {
					auto access = tenantUseCases(t.id).access;
					if (!access.isKnownUser(subject) && access.rightsFor(subject).source != "bootstrap") continue;
				}
				r ~= TenantRefDto(t.id, t.name);
			} catch (AccessDeniedException) {}
		}
		return r;
	}

	bool canBackup(string tenantId, AccessSubjectDto subject) {
		if (subject.systemAdministrator) return true;
		if (_registry.find(tenantId) is null) return false;
		return tenantUseCases(tenantId).access.rightsFor(subject).administrator;
	}

	// ---------------------------------------------------------------- tenant administration

	TenantDto[] listTenants(AccessSubjectDto subject) {
		requireSystemAdmin(subject);
		return sortedTenants.map!(t => toDto(t)).array;
	}

	TenantDto getTenant(string id, AccessSubjectDto subject) {
		requireSystemAdmin(subject);
		return toDto(require(id));
	}

	TenantDto createTenant(TenantCreateDto request, AccessSubjectDto subject) {
		requireSystemAdmin(subject);
		auto t = new Tenant;
		t.id = request.tenant.id.toLower;
		apply(t, request.tenant);
		t.validate();
		if (_registry.find(t.id) !is null) throw new ConflictException("Tenant '" ~ t.id ~ "' already exists");
		checkZoneUnique(t);
		t.createdAt = t.modifiedAt = now();
		t.createdBy = t.modifiedBy = subject.userName;
		_registry.save(t);
		try {
			auto uc = tenantUseCases(t.id);
			if (request.seedDemoData) uc.seeder.seed();
			if (request.adminUserName.length) createAdministrator(uc, request.adminUserName, request.adminEmail, subject.userName);
		} catch (Exception e) {
			// all or nothing: no half-initialised tenant remains
			_open.remove(t.id);
			_storages.destroy(t.id);
			_registry.remove(t.id);
			throw e;
		}
		return toDto(t);
	}

	TenantDto updateTenant(string id, TenantDto dto, AccessSubjectDto subject) {
		requireSystemAdmin(subject);
		auto t = require(id);
		apply(t, dto);
		t.validate();
		checkZoneUnique(t);
		t.modifiedAt = now();
		t.modifiedBy = subject.userName;
		_registry.save(t);
		return toDto(t);
	}

	void deleteTenant(string id, AccessSubjectDto subject) {
		requireSystemAdmin(subject);
		if (id == defaultTenantId) throw new ValidationException("id", "The default tenant cannot be deleted");
		require(id);
		takeBackup(id, BackupKind.PreDelete, "Final backup before deleting the tenant", subject.userName);
		_open.remove(id);
		_storages.destroy(id);
		_registry.remove(id);
	}

	// ---------------------------------------------------------------- backups

	BackupInfoDto[] listBackups(string tenantId, AccessSubjectDto subject) {
		requireBackup(tenantId, subject);
		BackupInfoDto[] r;
		foreach (bid; _backups.list(tenantId)) {
			try {
				auto info = readBackupInfo(_backups.load(tenantId, bid));
				info.id = bid;
				r ~= info;
			} catch (Exception e) {
				BackupInfoDto broken = { id: bid, tenant: tenantId, comment: "Unreadable: " ~ e.msg };
				r ~= broken;
			}
		}
		return r;
	}

	BackupInfoDto createBackup(string tenantId, string comment, AccessSubjectDto subject) {
		requireBackup(tenantId, subject);
		return takeBackup(tenantId, BackupKind.Manual, comment, subject.userName);
	}

	immutable(ubyte)[] backupFile(string tenantId, string backupId, AccessSubjectDto subject) {
		requireBackup(tenantId, subject);
		requireStored(tenantId, backupId);
		return _backups.load(tenantId, backupId);
	}

	void deleteBackup(string tenantId, string backupId, AccessSubjectDto subject) {
		requireBackup(tenantId, subject);
		requireStored(tenantId, backupId);
		_backups.remove(tenantId, backupId);
	}

	RestoreResultDto restoreBackup(string tenantId, string backupId, bool checkOnly, AccessSubjectDto subject) {
		requireBackup(tenantId, subject);
		requireStored(tenantId, backupId);
		auto r = restore(tenantId, decodeBackup(_backups.load(tenantId, backupId)), checkOnly, subject);
		r.backupId = backupId;
		return r;
	}

	RestoreResultDto restoreUpload(string tenantId, const(ubyte)[] file, bool checkOnly, bool keep, AccessSubjectDto subject) {
		requireBackup(tenantId, subject);
		auto snapshot = decodeBackup(file);
		string storedAs;
		if (keep && !checkOnly) {
			storedAs = newBackupId(tenantId, BackupKind.Upload);
			_backups.save(tenantId, storedAs, file);
		}
		auto r = restore(tenantId, snapshot, checkOnly, subject);
		r.backupId = storedAs.length ? storedAs : snapshot.info.id;
		return r;
	}

	size_t runScheduledBackups() {
		size_t n;
		foreach (t; sortedTenants) {
			if (t.status != TenantStatus.Active) continue;
			takeBackup(t.id, BackupKind.Scheduled, "", "scheduler");
			n++;
		}
		return n;
	}

	// ---------------------------------------------------------------- internals

	private RestoreResultDto restore(string tenantId, BackupSnapshot snapshot, bool checkOnly, AccessSubjectDto subject) {
		RestoreResultDto r;
		r.tenant = tenantId;
		r.sourceTenant = snapshot.info.tenant;
		r.backupCreatedAt = snapshot.info.createdAt;
		r.checkOnly = checkOnly;
		r.counts = snapshot.info.counts;
		r.elements = snapshot.info.elements;
		if (snapshot.info.tenant.length && snapshot.info.tenant != tenantId) {
			if (!subject.systemAdministrator)
				throw new AccessDeniedException("", format("The backup belongs to tenant '%s' - only a system administrator may restore it into '%s'",
					snapshot.info.tenant, tenantId));
			r.warnings ~= format("Backup of tenant '%s' is restored into tenant '%s'", snapshot.info.tenant, tenantId);
		}
		// entity sets plus the tenant's internal collections (journal, passwords, notifications)
		auto known = allSetNames() ~ ["Comments", "Credentials", "Activities", "NotificationStates"];
		foreach (name; snapshot.collections.keys)
			if (!known.canFind(name)) r.warnings ~= "Unknown collection '" ~ name ~ "' (from a newer version?) is kept but not used";

		// test load: every set must map into the current meta model
		auto probe = new class IDocumentStorage {
			Json[][string] data;
			Json[] load(string c) { return c in data ? data[c].dup : null; }
			void store(string c, Json[] d) { data[c] = d.dup; }
			string[] collections() { return data.keys; }
			string location() { return "restore check"; }
			void replaceAll(Json[][string] all) { data = all.dup; }
		};
		probe.replaceAll(snapshot.collections);
		auto test = _build(probe);
		static foreach (S; EamDtoSets) {
			try manage!S(test).list;
			catch (Exception e)
				throw new ValidationException("file", format("The backup cannot be loaded (%s): %s", S.setName, e.msg));
		}
		if (!subject.systemAdministrator && !test.access.rightsFor(subject).administrator)
			r.warnings ~= "After the restore you are no longer an administrator of this tenant";
		if (checkOnly) return r;

		r.safetyBackupId = takeBackup(tenantId, BackupKind.PreRestore,
			"Before restoring backup " ~ (snapshot.info.id.length ? snapshot.info.id : snapshot.info.createdAt), subject.userName).id;
		auto o = open(tenantId);
		o.storage.replaceAll(snapshot.collections);
		_open[tenantId] = Open(o.storage, _build(o.storage)); // repositories cache - rebuild them
		r.restored = true;
		return r;
	}

	private BackupInfoDto takeBackup(string tenantId, BackupKind kind, string comment, string actor) {
		auto t = require(tenantId);
		auto storage = open(tenantId).storage;
		Json[][string] data;
		foreach (c; storage.collections) data[c] = storage.load(c);
		BackupInfoDto info;
		info.id = newBackupId(tenantId, kind);
		info.tenant = tenantId;
		info.tenantName = t.name;
		info.createdAt = now();
		info.createdBy = actor;
		info.kind = kind.to!string;
		info.comment = comment;
		auto file = encodeBackup(info, data);
		_backups.save(tenantId, info.id, file);
		if (kind == BackupKind.Scheduled) applyRetention(tenantId);
		return info;
	}

	/// Keeps the newest `_retention` scheduled backups.
	private void applyRetention(string tenantId) {
		auto scheduled = _backups.list(tenantId).filter!(id => id.endsWith("-scheduled")).array;
		foreach (old; scheduled.length > _retention ? scheduled[_retention .. $] : null)
			_backups.remove(tenantId, old);
	}

	private string newBackupId(string tenantId, BackupKind kind) {
		auto t = Clock.currTime().toUTC();
		auto base = format("%04d%02d%02d-%02d%02d%02d", t.year, cast(int) t.month, t.day, t.hour, t.minute, t.second);
		auto suffix = kind.to!string.toLower;
		auto id = base ~ "-" ~ suffix;
		for (int i = 2; _backups.exists(tenantId, id); i++) id = format("%s-%d-%s", base, i, suffix);
		return id;
	}

	private Open open(string tenantId) {
		if (auto o = tenantId in _open) return *o;
		if (_registry.find(tenantId) is null) throw new EntityNotFoundException("Tenants", tenantId);
		auto storage = _storages.open(tenantId);
		auto o = Open(storage, _build(storage));
		_open[tenantId] = o;
		return o;
	}

	private void createAdministrator(IEamUseCases uc, string userName, string email, string actor) {
		PermissionDto all = { id: "perm-tenant-admin-all", name: "Tenant administration: all architecture data", entitySet: "All",
			canCreate: true, canUpdate: true, canDelete: true };
		uc.permissions.create(all, actor);
		string[] ids = ["perm-tenant-admin-all"];
		foreach (set; ["Users", "Roles", "Permissions"]) {
			PermissionDto p = { id: "perm-tenant-admin-" ~ set.toLower, name: "Tenant administration: " ~ set.toLower, entitySet: set,
				canCreate: true, canUpdate: true, canDelete: true };
			uc.permissions.create(p, actor);
			ids ~= p.id;
		}
		RoleDto role = { id: "role-tenant-admin", name: "Tenant Administrator", roleKey: "TENANT_ADMIN", permissionIds: ids };
		uc.roles.create(role, actor);
		// an existing user of that name (e.g. from the demo data) just gets the administrator role
		foreach (existing; uc.users.list)
			if (existing.userName.toLower == userName.toLower) {
				existing.roleIds ~= "role-tenant-admin";
				uc.users.update(existing.id, existing, actor);
				return;
			}
		UserDto user = { id: "usr-" ~ userName.toLower, name: userName, userName: userName, email: email, roleIds: ["role-tenant-admin"] };
		uc.users.create(user, actor);
	}

	private TenantDto toDto(Tenant t) {
		TenantDto d = { id: t.id, name: t.name, description: t.description, status: t.status.to!string, zoneId: t.zoneId,
			createdAt: t.createdAt, createdBy: t.createdBy, modifiedAt: t.modifiedAt, modifiedBy: t.modifiedBy };
		d.dataLocation = _storages.location(t.id);
		auto storage = open(t.id).storage;
		foreach (c; storage.collections) d.elements += storage.load(c).length;
		auto ids = _backups.list(t.id);
		d.backups = ids.length;
		if (ids.length) {
			try d.lastBackupAt = readBackupInfo(_backups.load(t.id, ids[0])).createdAt;
			catch (Exception) {}
		}
		return d;
	}

	private static void apply(Tenant t, TenantDto d) {
		t.name = d.name;
		t.description = d.description;
		t.zoneId = d.zoneId;
		try t.status = d.status.length ? d.status.to!TenantStatus : TenantStatus.Active;
		catch (Exception) throw new ValidationException("status", "Status must be Active or Suspended");
	}

	private void checkZoneUnique(Tenant t) {
		if (t.zoneId.length)
			foreach (o; _registry.all)
				if (o.id != t.id && o.zoneId == t.zoneId)
					throw new ValidationException("zoneId", "Zone '" ~ t.zoneId ~ "' is already mapped to tenant " ~ o.id);
	}

	private Tenant[] sortedTenants() {
		auto all = _registry.all;
		all.sort!((a, b) => (a.id == defaultTenantId) > (b.id == defaultTenantId) || ((a.id == defaultTenantId) == (b.id == defaultTenantId) && a.id < b.id));
		return all;
	}

	private Tenant require(string id) {
		auto t = _registry.find(id);
		if (t is null) throw new EntityNotFoundException("Tenants", id);
		return t;
	}

	private void requireStored(string tenantId, string backupId) {
		if (!_backups.exists(tenantId, backupId)) throw new EntityNotFoundException("Backups", backupId);
	}

	private static void requireSystemAdmin(AccessSubjectDto subject) {
		if (!subject.systemAdministrator)
			throw new AccessDeniedException("", "Tenant administration requires a system administrator");
	}

	private void requireBackup(string tenantId, AccessSubjectDto subject) {
		require(tenantId);
		if (!canBackup(tenantId, subject))
			throw new AccessDeniedException("", "Backup and restore require administrator rights in tenant '" ~ tenantId ~ "'");
	}

	private static string now() { return Clock.currTime().toUTC().toISOExtString(); }
}

private bool endsWith(string s, string suffix) pure @safe {
	return s.length >= suffix.length && s[$ - suffix.length .. $] == suffix;
}
