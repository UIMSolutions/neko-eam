/// Driving ports (use cases) used by all presentation adapters.
module neko.eam.ports.usecases;

public import neko.eam.application.dtos;
public import neko.eam.ports.services;

/// CRUD use cases of one element kind.
interface IManageElements(TDto) {
	string kind();
	TDto[] list();
	/// Throws EntityNotFoundException.
	TDto get(string id);
	/// `actor` is recorded as `modifiedBy`.
	TDto create(TDto dto, string actor = "system");
	TDto update(string id, TDto dto, string actor = "system");
	void remove(string id);
	size_t count();
}

/// Portfolio analysis use cases.
interface IAnalyzePortfolio {
	PortfolioReportDto portfolio();
	ImpactReportDto impact(string applicationId);
	CapabilityCoverageDto[] coverage();
	TechnologyRiskDto[] technologyRisks();
	ProductAlertDto[] productAlerts();
}

/// Central search across all element kinds (Fiori shell bar, CLI, desktop GUI).
interface ISearchElements {
	/// Hits for `query` (case insensitive), best matches first; at most `top` hits.
	SearchHitDto[] search(string query, size_t top = 50);
}

/// Import and export of entity sets as tables (format neutral; see ITableCodec for CSV / XLSX).
interface ITransferElements {
	/// All elements of `setName` with every field. `technicalHeaders` uses field names instead of labels.
	TableDto exportSet(string setName, bool technicalHeaders = false);
	/// One table per entity set, in import (dependency) order.
	TableDto[] exportAll(bool technicalHeaders = false);
	/// Upsert by ID: existing elements are updated with the columns present, new ones are created.
	/// Headers may be labels or field names. Rows that fail are reported, the others are imported;
	/// with `dryRun` nothing is saved.
	ImportResultDto importSet(string setName, TableDto table, string actor, bool dryRun = false);
	/// Imports every sheet whose name is an entity set name or label, in dependency order.
	ImportResultDto[] importAll(TableDto[] sheets, string actor, bool dryRun = false);
}

/// Authorization against the users, roles and permissions of the repository.
interface IAccessControl {
	/// Effective rights of `subject`.
	AccessRightsDto rightsFor(AccessSubjectDto subject);
	/// The use cases as `subject` may use them: every call is checked, forbidden calls throw
	/// AccessDeniedException; search and "export all" skip sets that may not be read.
	IEamUseCases useCasesFor(AccessSubjectDto subject);
	/// The subject matches an enabled user of this repository (needed to enter a non-default tenant).
	bool isKnownUser(AccessSubjectDto subject);
}

/// Loads a demo architecture if the repository is empty.
interface ISeedSampleData {
	/// Returns the number of created elements (0 if data already existed).
	size_t seed();
}

/// Facade of all driving ports.
interface IEamUseCases {
	IManageElements!ApplicationDto applications();
	IManageElements!BusinessCapabilityDto capabilities();
	IManageElements!ITComponentDto components();
	IManageElements!InformationFlowDto flows();
	IManageElements!OrganizationDto organizations();
	IManageElements!ProjectDto projects();
	IManageElements!ProductDto products();
	IManageElements!ProductGroupDto productGroups();
	IManageElements!ApplicationGroupDto applicationGroups();
	IManageElements!BusinessProcessDto businessProcesses();
	IManageElements!BusinessDataDto businessData();
	IManageElements!ServiceProductGroupDto serviceProductGroups();
	IManageElements!StrategicGuidelineDto strategicGuidelines();
	IManageElements!ServiceCapabilityDto serviceCapabilities();
	IManageElements!MeasureGroupDto measureGroups();
	IManageElements!MeasureDto measures();
	IManageElements!ArchitecturePrincipleDto architecturePrinciples();
	IManageElements!ArchitectureGuidelineDto architectureGuidelines();
	IManageElements!ReferenceArchitectureDto referenceArchitectures();
	IManageElements!ArchitectureDocumentDto architectureDocuments();
	IManageElements!SubProjectDto subProjects();
	IManageElements!WorkPackageDto workPackages();
	IManageElements!EnterpriseDto enterprises();
	IManageElements!MemberDto members();
	IManageElements!ITProcessDto itProcesses();
	IManageElements!ProcessStepDto processSteps();
	IManageElements!ProcessKpiDto processKpis();
	IManageElements!ProtectionRequirementDto protectionRequirements();
	IManageElements!SecurityRiskDto securityRisks();
	IManageElements!SecurityControlDto securityControls();
	IManageElements!ReportDto reports();
	IManageElements!ReportBookDto reportBooks();
	IManageElements!UserDto users();
	IManageElements!RoleDto roles();
	IManageElements!PermissionDto permissions();
	ISearchElements search();
	ITransferElements transfer();
	IAnalyzePortfolio analysis();
	ISeedSampleData seeder();
	IArchiMateExport archimate();
	IAccessControl access();
	IReporting reporting();
	IComments comments();
}

/// Typed access to the use cases of a DtoSet from the registry.
auto manage(alias S)(IEamUseCases uc) {
	return __traits(getMember, uc, S.accessor)();
}

/// Platform level (above the tenants): tenant resolution and administration, backup and restore.
/// Every operation that takes a subject checks it: tenant administration needs a system administrator,
/// backups of a tenant an administrator of that tenant (full rights incl. access management) or a system administrator.
interface IEamPlatform {
	/// Tenant for a request: the tenant mapped to the caller's identity zone, otherwise `requested`
	/// (or the default tenant). Throws AccessDeniedException if the caller may not enter it.
	string resolveTenant(AccessSubjectDto subject, string requested);
	/// Use cases of a tenant (unchecked - wrap with `access.useCasesFor`).
	IEamUseCases tenantUseCases(string tenantId);
	/// Tenants the caller may switch to.
	TenantRefDto[] tenantsFor(AccessSubjectDto subject);
	bool canBackup(string tenantId, AccessSubjectDto subject);

	TenantDto[] listTenants(AccessSubjectDto subject);
	TenantDto getTenant(string id, AccessSubjectDto subject);
	TenantDto createTenant(TenantCreateDto request, AccessSubjectDto subject);
	TenantDto updateTenant(string id, TenantDto tenant, AccessSubjectDto subject);
	/// Takes a final backup (kept), then removes the tenant and its data. The default tenant cannot be removed.
	void deleteTenant(string id, AccessSubjectDto subject);

	BackupInfoDto[] listBackups(string tenantId, AccessSubjectDto subject);
	BackupInfoDto createBackup(string tenantId, string comment, AccessSubjectDto subject);
	immutable(ubyte)[] backupFile(string tenantId, string backupId, AccessSubjectDto subject);
	void deleteBackup(string tenantId, string backupId, AccessSubjectDto subject);
	/// Checks (checksum, format, test load) and - unless `checkOnly` - restores a stored backup.
	/// A safety backup of the current state is taken first. Backups of other tenants need a system administrator.
	RestoreResultDto restoreBackup(string tenantId, string backupId, bool checkOnly, AccessSubjectDto subject);
	/// Same for an uploaded backup file; with `keep` the file is stored as backup of kind Upload.
	RestoreResultDto restoreUpload(string tenantId, const(ubyte)[] file, bool checkOnly, bool keep, AccessSubjectDto subject);
	/// Scheduled backup of every active tenant (and retention). Returns the number of backups taken.
	size_t runScheduledBackups();
}

/// Reporting: runs stored report definitions (and report books) with the rights of the caller.
interface IReporting {
	ReportResultDto run(string reportId, string actor = "system");
	/// All reports of a report book, in its order.
	ReportResultDto[] runBook(string bookId, string actor = "system");
	/// Runs an unsaved definition (preview).
	ReportResultDto runDefinition(ReportDto definition, string actor = "system");
}

/// Running comments (journal) of any element: date, author, text. Append-only - entries are not edited.
interface IComments {
	/// Comments of an element, newest first. Requires read access to the element.
	CommentDto[] list(string elementSet, string elementId, string actor = "");
	/// Adds a comment by `actor`. Requires read access to the element.
	CommentDto add(string elementSet, string elementId, string text, string actor);
	/// Deletes a comment: its author, or a user who may delete elements of that set.
	void remove(string commentId, string actor);
	size_t count(string elementSet, string elementId);
}
