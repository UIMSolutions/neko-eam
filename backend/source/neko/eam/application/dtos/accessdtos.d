/// Data transfer objects of the access control (authorization against users, roles and permissions).
module neko.eam.application.dtos.accessdtos;

/// Who is calling, as seen by a presentation adapter after authentication.
struct AccessSubjectDto {
	string userName;      /// login name (JWT user name, OS user, --user, dev cookie)
	string email;
	/// Break-glass: XSUAA Admin scope or local operation without impersonation - bypasses all checks.
	bool administrator;
	/// Platform operator: XSUAA SystemAdmin scope or local operator - manages tenants, enters every tenant.
	bool systemAdministrator;
	/// XSUAA identity zone (subaccount) of the caller - selects the tenant mapped to it.
	string zoneId;
}

/// Rights on one entity set.
struct SetRightsDto {
	string setName;
	bool read;
	bool create;
	bool update;
	bool remove;
}

/// Effective rights of the caller (shown in the Fiori profile, used to hide navigation and buttons).
struct AccessRightsDto {
	string userName;
	string userId;        /// id of the matched repository user ("" if none)
	string displayName;
	bool unrestricted;
	/// Unrestricted or full rights on everything incl. users, roles and permissions (may back up / restore).
	bool administrator;
	/// "administrator", "user", "bootstrap" (no users defined yet), "unknown user", "disabled user"
	string source;
	string[] roles;       /// names of the active roles
	string summary;       /// e.g. "All: R; Applications: RCUD"
	SetRightsDto[] sets;
}
