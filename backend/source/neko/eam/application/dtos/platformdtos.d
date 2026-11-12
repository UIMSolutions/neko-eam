/// Data transfer objects of the platform level: tenants (Mandanten), backups and restores.
module neko.eam.application.dtos.platformdtos;

struct TenantDto {
	string id;
	string name;
	string description;
	string status = "Active";
	string zoneId;
	string createdAt, createdBy, modifiedAt, modifiedBy;
	string dataLocation;   /// storage location (read-only)
	size_t elements;       /// number of elements (read-only)
	size_t backups;        /// number of stored backups (read-only)
	string lastBackupAt;   /// read-only
}

/// Options when creating a tenant.
struct TenantCreateDto {
	TenantDto tenant;
	bool seedDemoData;     /// load the demo architecture into the new tenant
	string adminUserName;  /// creates an administrator user (with role and permissions) in the new tenant
	string adminEmail;
}

/// A tenant the caller may switch to (Fiori profile, CLI).
struct TenantRefDto {
	string id;
	string name;
}

struct SetCountDto {
	string setName;
	size_t count;
}

/// Description of a stored backup (without its data).
struct BackupInfoDto {
	string id;
	string tenant;
	string tenantName;
	string createdAt;
	string createdBy;
	string kind;           /// Manual, Scheduled, PreRestore, PreDelete, Upload
	string comment;
	size_t elements;
	size_t sizeBytes;
	string checksum;       /// SHA-256 of the canonical data
	SetCountDto[] counts;
}

/// Result of checking or restoring a backup.
struct RestoreResultDto {
	string tenant;         /// restored into
	string sourceTenant;   /// tenant the backup was taken from
	string backupId;
	string backupCreatedAt;
	bool checkOnly;
	bool restored;
	string safetyBackupId; /// backup of the state before the restore
	size_t elements;
	SetCountDto[] counts;
	string[] warnings;
}

/// One column of a report result.
struct ReportColumnDto {
	string name;
	string label;
	string type;
}

/// One group of a grouped report (count and optional sum).
struct ReportGroupDto {
	string value;
	size_t count;
	double sum = 0;
}

/// Executed report: formatted cells (references resolved to names), optional group summary.
struct ReportResultDto {
	string reportId;
	string name;
	string description;
	string setName;
	string setLabel;
	string filter;
	string orderBy;
	string generatedAt;
	string generatedBy;
	size_t totalCount;      /// rows matching the filter (before Max Rows)
	ReportColumnDto[] columns;
	string[][] rows;
	string groupBy;
	string groupLabel;
	string sumField;
	string sumLabel;
	double totalSum = 0;
	ReportGroupDto[] groups;
}

/// Journal entry of an element.
struct CommentDto {
	string id;
	string elementSet;
	string elementId;
	string text;
	string createdAt;
	string createdBy;
	/// the caller may delete it (author, or delete permission on the element's set)
	bool deletable;
}
