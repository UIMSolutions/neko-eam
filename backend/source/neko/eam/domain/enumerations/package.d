/// Business enumerations of the EAM domain (Neko-like meta model).
module neko.eam.domain.enumerations;

/// Lifecycle phase of an architecture element (applications, IT components).
enum LifecycleStatus { Plan, Build, Active, PhaseOut, Retired }

/// Business criticality of an application.
enum Criticality { Low, Medium, High, MissionCritical }

/// Gartner TIME classification used for application portfolio rationalisation.
enum TimeCategory { Tolerate, Invest, Migrate, Eliminate }

/// Category of a technical (IT) component.
enum TechnologyCategory { Software, Platform, Database, Middleware, Hardware, Cloud }

/// Technical type of an information flow (interface) between two applications.
enum InterfaceType { Api, File, Message, Database, Manual }

/// Status of a transformation project / work package.
enum ProjectStatus { Proposed, Approved, InProgress, Completed, Cancelled }

/// Type of an organisational unit.
enum OrganizationType { Company, BusinessUnit, Department, Team, External }

/// Administrative state of a master data object (product groups, application groups, applications).
enum ObjectState { Draft, Active, Inactive, Archived }

/// Release / approval workflow state of a product version.
enum ApprovalStatus { Requested, InReview, Approved, ApprovedWithConditions, Rejected }

/// Status of a product version in the product catalogue.
enum ProductStatus { Draft, Released, Deprecated, Withdrawn }

/// Protection requirement (BSI IT-Grundschutz "Schutzbedarf").
enum ProtectionLevel { Normal, High, VeryHigh }

/// Kind of a product version.
enum VersionType { Major, Minor, Patch, ServicePack, Build }

/// Result of a risk evaluation.
enum RiskLevel { Low, Medium, High, Critical }

/// Kind of a product lifecycle alert.
enum ProductAlertKind { EndOfSupport, EndOfSecurity, EndOfLife, BsiPermissionExpired, Blacklisted, ReminderDue, ValidationOverdue }

/// Outcome of a data protection impact assessment (DSGVO Art. 35 / DPIA).
enum DpiaRating { NotAssessed, NotRequired, Low, Medium, High }

/// Kind of a service / product catalogue.
enum CatalogType { BusinessService, TechnicalService, SupportService, ServiceProduct }

/// Topic of a strategic IT guideline (IT landscape planning).
enum GuidelineCategory { Business, Architecture, Technology, Data, Security, Sourcing, Compliance }

/// Priority of a planning object (guidelines, measures).
enum PlanningPriority { Low, Medium, High, Critical }

/// Planning / approval status of measures and measure groups.
enum PlanningStatus { Draft, Proposed, Approved, InProgress, Completed, Rejected, Cancelled }

/// Kind of change a measure applies to the IT landscape.
enum MeasureType { Introduce, Modernize, Migrate, Consolidate, Retire, Optimize, Invest }

/// Architecture domain an architecture specification applies to.
enum ArchitectureDomain { Business, Data, Application, Technology, Security, Integration }

/// Review / approval status of architecture specifications (principles, guidelines, reference architectures, documents).
enum SpecificationStatus { Draft, InReview, Approved, Deprecated, Withdrawn }

/// How binding an architecture guideline is.
enum ObligationLevel { Mandatory, Recommended, Optional }

/// Kind of an architecture document.
enum DocumentType { Concept, Specification, Standard, Decision, Policy, Manual, Template, Report }

/// Information classification of a document.
enum Confidentiality { Public, Internal, Confidential, Restricted }

/// Phase of a project (project management).
enum ProjectPhase { Initiation, Planning, Execution, Closing }

/// Status of a work package.
enum WorkPackageStatus { NotStarted, InProgress, OnHold, Completed, Cancelled }

/// Entity sets a permission can refer to. `All` covers every set except the access management sets
/// (Users, Roles, Permissions), which always need an explicit permission. Kept in sync with the DTO
/// registry by a compile-time check.
enum EntitySetName {
	All, Applications, ApplicationGroups, Products, ProductGroups, ITComponents, BusinessCapabilities,
	BusinessProcesses, BusinessData, Organizations, ServiceProductGroups, StrategicGuidelines,
	ServiceCapabilities, MeasureGroups, Measures, ArchitecturePrinciples, ArchitectureGuidelines,
	ReferenceArchitectures, ArchitectureDocuments, Projects, SubProjects, WorkPackages, InformationFlows,
	Enterprises, Members, ITProcesses, ProcessSteps, ProcessKpis, ProtectionRequirements, SecurityRisks,
	SecurityControls, Reports, ReportBooks, Users, Roles, Permissions
}

/// Operation on an entity set that is subject to authorization.
enum AccessAction { Read, Create, Update, Delete }

/// Function of a member within an organisational unit.
enum MemberFunction { Head, Deputy, Employee, Assistant }

/// Employment relationship of a member.
enum EmploymentType { Internal, External, Contractor, Trainee }

/// Operating state of a tenant (Mandant).
enum TenantStatus { Active, Suspended }

/// Why a backup was taken.
enum BackupKind { Manual, Scheduled, PreRestore, PreDelete, Upload }

/// Reference framework of an IT process.
enum ProcessFramework { ITIL4, COBIT, ISO20000, IT4IT, Internal }

/// Kind of a process step.
enum StepType { Activity, Decision, Approval, Automated, Handover }

/// Degree of automation of a process step.
enum AutomationLevel { Manual, PartlyAutomated, Automated }

/// Whether a KPI is better when high or when low.
enum KpiDirection { HigherIsBetter, LowerIsBetter }

/// Evaluation of a KPI against its target and threshold.
enum KpiStatus { NoData, OnTrack, AtRisk, OffTrack }

/// Risk treatment option (ISO 27005).
enum RiskTreatment { Mitigate, Accept, Transfer, Avoid }

/// Life cycle of a security risk.
enum RiskStatus { Identified, Assessed, InTreatment, Accepted, Closed }

/// Catalogue a security control comes from.
enum ControlFramework { ISO27001, BSIGrundschutz, NIST, CIS, Internal }

/// Effect of a security control.
enum ControlType { Preventive, Detective, Corrective }

/// Implementation state of a security control.
enum ImplementationStatus { Planned, InProgress, Implemented, NotApplicable }
