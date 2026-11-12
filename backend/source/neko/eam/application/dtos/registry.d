/// Compile-time registry of all element kinds exposed by the driving adapters (OData, CLI, GUI, Web).
module neko.eam.application.dtos.registry;

import std.meta : AliasSeq;
import neko.eam.domain.entities;
import neko.eam.domain.enumerations : EntitySetName;
import neko.eam.application.dtos.elementdtos;

/// Describes one entity set: OData set name, IEamUseCases accessor, DTO and entity type,
/// entity type name, display label and SAP icon name (used by the Fiori side navigation).
struct DtoSet(string setName_, string accessor_, TDto, TEntity, string typeName_, string label_, string icon_) {
	enum setName = setName_;
	enum accessor = accessor_;
	alias Dto = TDto;
	alias Entity = TEntity;
	enum typeName = typeName_;
	enum label = label_;
	enum icon = icon_;
}

alias EamDtoSets = AliasSeq!(
	DtoSet!("Applications", "applications", ApplicationDto, Application, "Application", "Applications", "product"),
	DtoSet!("BusinessCapabilities", "capabilities", BusinessCapabilityDto, BusinessCapability, "BusinessCapability", "Business Capabilities", "org-chart"),
	DtoSet!("ITComponents", "components", ITComponentDto, ITComponent, "ITComponent", "IT Components", "it-system"),
	DtoSet!("InformationFlows", "flows", InformationFlowDto, InformationFlow, "InformationFlow", "Information Flows", "chain-link"),
	DtoSet!("Organizations", "organizations", OrganizationDto, Organization, "Organization", "Organisation Units", "group"),
	DtoSet!("Projects", "projects", ProjectDto, Project, "Project", "Projects", "project-definition-triangle-2"),
	DtoSet!("Products", "products", ProductDto, Product, "Product", "Products", "product"),
	DtoSet!("ProductGroups", "productGroups", ProductGroupDto, ProductGroup, "ProductGroup", "Product Groups", "folder-blank"),
	DtoSet!("ApplicationGroups", "applicationGroups", ApplicationGroupDto, ApplicationGroup, "ApplicationGroup", "Application Groups", "tree"),
	DtoSet!("BusinessProcesses", "businessProcesses", BusinessProcessDto, BusinessProcess, "BusinessProcess", "Business Processes", "process"),
	DtoSet!("BusinessData", "businessData", BusinessDataDto, BusinessData, "BusinessData", "Business Data", "database"),
	DtoSet!("ServiceProductGroups", "serviceProductGroups", ServiceProductGroupDto, ServiceProductGroup, "ServiceProductGroup", "Service Product Groups", "course-book"),
	DtoSet!("StrategicGuidelines", "strategicGuidelines", StrategicGuidelineDto, StrategicGuideline, "StrategicGuideline", "Strategic Guidelines", "compass"),
	DtoSet!("ServiceCapabilities", "serviceCapabilities", ServiceCapabilityDto, ServiceCapability, "ServiceCapability", "Service Capabilities", "puzzle"),
	DtoSet!("MeasureGroups", "measureGroups", MeasureGroupDto, MeasureGroup, "MeasureGroup", "Measure Groups", "folder-full"),
	DtoSet!("Measures", "measures", MeasureDto, Measure, "Measure", "Measures", "activity-items"),
	DtoSet!("ArchitecturePrinciples", "architecturePrinciples", ArchitecturePrincipleDto, ArchitecturePrinciple, "ArchitecturePrinciple", "Architecture Principles", "accept"),
	DtoSet!("ArchitectureGuidelines", "architectureGuidelines", ArchitectureGuidelineDto, ArchitectureGuideline, "ArchitectureGuideline", "Architecture Guidelines", "checklist-2"),
	DtoSet!("ReferenceArchitectures", "referenceArchitectures", ReferenceArchitectureDto, ReferenceArchitecture, "ReferenceArchitecture", "Reference Architectures", "building"),
	DtoSet!("ArchitectureDocuments", "architectureDocuments", ArchitectureDocumentDto, ArchitectureDocument, "ArchitectureDocument", "Architecture Documents", "document-text"),
	DtoSet!("SubProjects", "subProjects", SubProjectDto, SubProject, "SubProject", "Sub Projects", "tree"),
	DtoSet!("WorkPackages", "workPackages", WorkPackageDto, WorkPackage, "WorkPackage", "Work Packages", "task"),
	DtoSet!("Enterprises", "enterprises", EnterpriseDto, Enterprise, "Enterprise", "Organisations", "building"),
	DtoSet!("Members", "members", MemberDto, Member, "Member", "Members", "person-placeholder"),
	DtoSet!("ITProcesses", "itProcesses", ITProcessDto, ITProcess, "ITProcess", "IT Processes", "process"),
	DtoSet!("ProcessSteps", "processSteps", ProcessStepDto, ProcessStep, "ProcessStep", "Process Steps", "step"),
	DtoSet!("ProcessKpis", "processKpis", ProcessKpiDto, ProcessKpi, "ProcessKpi", "Process KPIs", "measure"),
	DtoSet!("ProtectionRequirements", "protectionRequirements", ProtectionRequirementDto, ProtectionRequirement, "ProtectionRequirement", "Protection Requirements", "shield"),
	DtoSet!("SecurityRisks", "securityRisks", SecurityRiskDto, SecurityRisk, "SecurityRisk", "Security Risks", "warning"),
	DtoSet!("SecurityControls", "securityControls", SecurityControlDto, SecurityControl, "SecurityControl", "Security Controls", "locked"),
	DtoSet!("Reports", "reports", ReportDto, Report, "Report", "Reports", "table-view"),
	DtoSet!("ReportBooks", "reportBooks", ReportBookDto, ReportBook, "ReportBook", "Report Books", "course-book"),
	DtoSet!("Users", "users", UserDto, User, "User", "Users", "employee"),
	DtoSet!("Roles", "roles", RoleDto, Role, "Role", "Roles", "role"),
	DtoSet!("Permissions", "permissions", PermissionDto, Permission, "Permission", "Permissions", "locked"),
);

// every entity set can be the target of a permission (domain enumeration EntitySetName)
static foreach (S; EamDtoSets)
	static assert(__traits(hasMember, EntitySetName, S.setName), S.setName ~ " is missing in EntitySetName");
static assert([__traits(allMembers, EntitySetName)].length == EamDtoSets.length + 1, "EntitySetName has unknown sets");

/// Runtime list of all set names.
string[] allSetNames() {
	string[] names;
	static foreach (S; EamDtoSets) names ~= S.setName;
	return names;
}

/// Labels are column headers of CSV / XLSX files - they must be unique within a set.
unittest {
	import neko.eam.application.dtos.modelinfo : describeFields;
	static foreach (S; EamDtoSets) {{
		bool[string] seen;
		foreach (f; describeFields!S()) {
			assert(f.label !in seen, S.setName ~ ": duplicate label '" ~ f.label ~ "'");
			seen[f.label] = true;
		}
	}}
}
