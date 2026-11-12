/// Technical storage models (one JSON document per element). Schema version is stored per document.
module neko.eam.persistence.records;

mixin template RecordFields() {
	int schemaVersion = 1;
	string id;
	string name;
	string description;
	string createdAt;
	string createdBy;
	string modifiedAt;
	string modifiedBy;
}

struct ApplicationRecord {
	mixin RecordFields;
	string release, status, criticality, timeCategory;
	int businessValue, technicalFit;
	double annualCost = 0;
	string goLiveDate, retirementDate, ownerOrganizationId;
	string[] capabilityIds, componentIds;
	string levelId; /// Level ID
	string objectState = "Active"; /// Object State
	string applicationGroupId; /// Parent Application Group
	string stakeholder; /// Stakeholder
	string[] usedProductIds; /// Used Products
	string[] assignedProductIds; /// Assigned Products
	int totalUsedProducts; /// Insgesamt genutzte Produkte
	int totalAssignedProducts; /// Insgesamt zugewiesene Produkte
}

struct BusinessCapabilityRecord {
	mixin RecordFields;
	int level, strategicImportance;
	string parentId, ownerOrganizationId;
	string levelId; /// Level ID
	string missionCriticality = "Medium"; /// Mission Criticality
	string stakeholder; /// Stakeholder
}

struct BusinessProcessRecord {
	mixin RecordFields;
	string levelId; /// Level ID
	string processManager; /// Process Manager
	string processOwner; /// Process Owner
	string status = "Active"; /// Status
	string parentProcessId; /// Parent Business Process
}

struct BusinessDataRecord {
	mixin RecordFields;
	string dataVersion; /// Version
	string capabilityId; /// Business Capability
	string businessObject; /// Business Object
	string dpiaRating = "NotAssessed"; /// DPIA Rating
	string[] informationFlowIds; /// Information Flows
	string ownerOrganizationId; /// Owner
}

struct ServiceProductGroupRecord {
	mixin RecordFields;
	string shortName; /// Short Name
	string catalogType = "BusinessService"; /// Catalog Type
	string catalogueManager; /// Catalogue Manager
	string releaseDate; /// Date of Release
	string status = "Draft"; /// Status
	string catalogVersion; /// Version
	string parentId; /// Parent Catalog
}

struct StrategicGuidelineRecord {
	mixin RecordFields;
	string shortName; /// Short Name
	string category = "Architecture"; /// Category
	string priority = "Medium"; /// Priority
	string status = "Draft"; /// Status
	string rationale; /// Rationale
	string implications; /// Implications
	string guidelineOwner; /// Guideline Owner
	string ownerOrganizationId; /// Responsible Organization
	string validFrom, validUntil; /// Valid From, Valid Until
	string parentId; /// Parent Guideline
	string[] capabilityIds; /// Business Capabilities
}

struct ServiceCapabilityRecord {
	mixin RecordFields;
	string shortName; /// Short Name
	string levelId; /// Level ID
	string status = "Active"; /// Status
	string missionCriticality = "Medium"; /// Mission Criticality
	int currentMaturity = 1; /// Current Maturity
	int targetMaturity = 3; /// Target Maturity
	string stakeholder; /// Stakeholder
	string ownerOrganizationId; /// Responsible Organization
	string parentId; /// Parent Service Capability
	string businessCapabilityId; /// Business Capability
	string[] serviceProductGroupIds; /// Service Catalogues
	string[] applicationIds; /// Supporting Applications
	// maturityGap is derived and not stored
}

struct MeasureGroupRecord {
	mixin RecordFields;
	string shortName; /// Short Name
	string status = "Draft"; /// Status
	string responsible; /// Responsible
	string ownerOrganizationId; /// Responsible Organization
	string startDate, endDate; /// Planning Period
	double budget = 0; /// Budget
	string parentGroupId; /// Parent Measure Group
	string[] strategicGuidelineIds; /// Strategic Guidelines
	// totals are rolled up from the measures at read time and not stored
}

struct MeasureRecord {
	mixin RecordFields;
	string shortName; /// Short Name
	string measureType = "Modernize"; /// Measure Type
	string priority = "Medium"; /// Priority
	string status = "Draft"; /// Status
	int progress; /// Progress (%)
	string responsible; /// Responsible
	string ownerOrganizationId; /// Responsible Organization
	string startDate, endDate; /// Start Date, End Date
	double estimatedCost = 0; /// Estimated Cost
	string expectedBenefit; /// Expected Benefit
	string measureGroupId; /// Measure Group
	string projectId; /// Implementing Project
	string[] strategicGuidelineIds; /// Strategic Guidelines
	string[] serviceCapabilityIds; /// Service Capabilities
	string[] affectedApplicationIds; /// Affected Applications
	string[] affectedComponentIds; /// Affected IT Components
}

struct ArchitecturePrincipleRecord {
	mixin RecordFields;
	string shortName, domain = "Application", priority = "Medium", status = "Draft", specVersion;
	string statement, rationale, implications; /// Statement, Rationale, Implications
	string principleOwner, ownerOrganizationId; /// Principle Owner, Responsible Organization
	string validFrom, validUntil;
	string[] strategicGuidelineIds;
}

struct ArchitectureGuidelineRecord {
	mixin RecordFields;
	string shortName, domain = "Application", obligation = "Recommended", status = "Draft", specVersion;
	string applicability, verification; /// Applicability, Compliance Verification
	string guidelineOwner, ownerOrganizationId;
	string validFrom, validUntil;
	string[] principleIds, standardProductIds, componentIds;
}

struct ReferenceArchitectureRecord {
	mixin RecordFields;
	string shortName, domain = "Application", status = "Draft", specVersion;
	string scopeDescription, architect, ownerOrganizationId;
	string validFrom, validUntil;
	string parentId;
	string[] principleIds, guidelineIds, capabilityIds, componentIds, standardProductIds, applicationIds;
	// hierarchyPath and totalDocuments are derived at read time
}

struct ArchitectureDocumentRecord {
	mixin RecordFields;
	string documentNumber, documentType = "Concept", status = "Draft", docVersion, confidentiality = "Internal";
	string author, approver, approvalDate, nextReviewDate, documentLink, ownerOrganizationId;
	string[] referenceArchitectureIds, principleIds, guidelineIds, applicationIds;
	// reviewOverdue is derived at read time
}

struct UserRecord {
	mixin RecordFields;
	string userName, email;
	bool active = true;
	string validUntil, organizationId;
	string[] roleIds;
	// effectiveRights is derived at read time
}

struct RoleRecord {
	mixin RecordFields;
	string roleKey, status = "Active";
	string[] permissionIds;
}

struct PermissionRecord {
	mixin RecordFields;
	string entitySet = "All";
	bool canRead = true, canCreate, canUpdate, canDelete;
}

struct ITProcessRecord {
	mixin RecordFields;
	string shortName, levelId, framework = "ITIL4", status = "Active", processOwner, processManager, ownerOrganizationId, purpose, parentProcessId;
	int currentMaturity = 1, targetMaturity = 3;
	string[] businessProcessIds, serviceProductGroupIds;
}

struct ProcessStepRecord {
	mixin RecordFields;
	string processId, stepType = "Activity", automationLevel = "Manual", performerRole, responsibleOrganizationId, inputs, outputs;
	int sequenceNo = 10;
	double durationHours = 0;
	string[] applicationIds;
}

struct ProcessKpiRecord {
	mixin RecordFields;
	string processId, unit, direction = "HigherIsBetter", measuredAt, frequency, kpiOwner;
	double targetValue = 0, thresholdValue = 0, actualValue = 0;
	bool measured;
}

struct ProtectionRequirementRecord {
	mixin RecordFields;
	string applicationId, businessDataId, componentId;
	string confidentiality = "Normal", integrity = "Normal", availability = "Normal";
	string justification, status = "Draft", assessedBy, assessmentDate, nextReviewDate;
}

struct SecurityRiskRecord {
	mixin RecordFields;
	string riskNumber, threat, vulnerability, treatment = "Mitigate", status = "Identified", riskOwner, dueDate;
	int likelihood = 3, impact = 3, residualLikelihood, residualImpact;
	string[] applicationIds, componentIds, businessDataIds, controlIds;
}

struct SecurityControlRecord {
	mixin RecordFields;
	string controlReference, framework = "ISO27001", controlType = "Preventive", implementationStatus = "Planned";
	string controlOwner, dueDate, lastReviewDate;
	int effectiveness;
	string[] applicationIds, componentIds;
}

struct ReportRecord {
	mixin RecordFields;
	string category, entitySet = "Applications", filter, orderBy, groupBy, sumField, reportOwner;
	string[] columns;
	int maxRows;
}

struct ReportBookRecord {
	mixin RecordFields;
	string audience, reportOwner;
	string[] reportIds;
}

struct ITComponentRecord {
	mixin RecordFields;
	string vendor, release, category, status, endOfSupportDate;
	double licenseCost = 0;
}

struct InformationFlowRecord {
	mixin RecordFields;
	string sourceApplicationId, targetApplicationId, flowType, dataObject, frequency;
}

struct OrganizationRecord {
	mixin RecordFields;
	string orgType, location, parentId;
	string shortName; /// Short Name
	string architect; /// Architect
	string contact; /// Contact
	string stakeholder; /// Stakeholder
	string startDate, endDate; /// Start Date, End Date
	string status = "Active"; /// Status
	int totalConsumedBusinessServices; /// Total Consumed Business Services
	int totalProvidedBusinessServices; /// Total Provided Business Services
	int totalProvidedSupportServices; /// Total Provided Support Services
	string enterpriseId; /// Organisation (legal entity)
	string costCenter; /// Cost Center
	// hierarchyPath ("Organisation") and the staffing figures are derived at read time and not stored
}

struct EnterpriseRecord {
	mixin RecordFields;
	string shortName, legalForm, registrationNumber, vatId, headquarters, country, industry, website, foundingDate;
	string status = "Active";
	string parentEnterpriseId;
	// managingDirector, hierarchyPath and the totals are derived at read time
	double ownershipShare = 0;
}

struct MemberRecord {
	mixin RecordFields;
	string personnelNumber, jobTitle, organizationId, memberFunction = "Employee", employmentType = "Internal";
	int capacity = 100;
	string email, phone, location, startDate, endDate, managerId, userId;
}

struct ProjectRecord {
	mixin RecordFields;
	string status, startDate, endDate;
	double budget = 0;
	string sponsorOrganizationId;
	string[] affectedApplicationIds;
	string projectNumber, projectManager; /// Project Number, Project Manager
	string priority = "Medium", phase = "Initiation"; /// Priority, Phase
	double actualCost = 0; /// Actual Cost
	// totals and progress are rolled up from sub projects / work packages at read time
}

struct SubProjectRecord {
	mixin RecordFields;
	string shortName, projectId, parentSubProjectId, subProjectManager, status = "Proposed";
	string startDate, endDate;
	double budget = 0;
	string ownerOrganizationId;
	string[] affectedApplicationIds;
}

struct WorkPackageRecord {
	mixin RecordFields;
	string wbsCode, projectId, subProjectId, responsible, status = "NotStarted";
	string startDate, endDate;
	double plannedEffortDays = 0, actualEffortDays = 0, plannedCost = 0, actualCost = 0;
	int progress;
	string deliverables;
	string[] predecessorIds, measureIds, affectedApplicationIds;
	// delayed is derived at read time
}

struct ProductRecord {
	mixin RecordFields;
	string componentId; /// Component
	string productVersion; /// Version
	string majorVersion; /// Major Version
	string versionType = "Major"; /// Version Type
	string productEdition; /// Product Edition
	string productGroupId; /// Product Group
	string productType; /// Product Type
	string vendor; /// Vendor
	string vendorWeblink; /// Vendor Weblink
	string downloadLink; /// Download link of the product version
	string status = "Draft"; /// Status
	string lifecycleStatus = "Active"; /// Lifecycle Status
	string approvalStatus = "Requested"; /// Approval Status
	string softwareCategory; /// Software Category
	string softwareClass; /// Softwareclass
	string standardClassification; /// Standard Classification
	string maximoClassificationPath; /// Maximo Classification Path
	string cpeId; /// Common Platform Enumeration-Kennung
	string certlichId; /// CERTlich ID
	string pulsId; /// PuLS ID
	string source; /// Source
	bool appliance; /// Appliance
	string startDate; /// Start Date
	string endDate; /// End Date
	string endOfSupport; /// End of Support
	string endOfSecurity; /// End of Security
	string endOfLife; /// End of Life
	string endOfSupportContract; /// End of Support Contract
	string bsiPermissionEndDate; /// Enddate BSI Permission
	string dueDateNextValidation; /// Due Date next Validation
	int updateCycleWeeks; /// Update Cycle in Weeks
	int eolReminderDays; /// Number of days before EOL reminder shall be send
	int milestoneReminderDays; /// Number of days before milestone reminder shall be send
	string eolReminderDate; /// Reminder EoL (Date)
	int eosuReminderDays; /// Reminder EoSu (in Days)
	string eosuReminderDate; /// Reminder EoSu (Date)
	string licenceCategory; /// Licence Category
	string licensingModel; /// Licensing Model
	double licenseCosts = 0; /// License costs
	string licenseOwner; /// License owner
	bool purchasableLicenseRequired; /// Purchasable License required
	int numberOfInstallations; /// Number of Installations
	bool modifyOssSourcecode; /// Modify OSS Sourcecode
	bool isBlacklisted; /// IsBlacklisted
	string riskEvaluation = "Low"; /// Risk Evaluation
	string protection = "Normal"; /// Protection
	string dataProtectionRequirements = "Normal"; /// Data Protection Requirements
	bool ipv6Communication; /// IPv6 Kommunikation
	bool sendsDataToPublicCloud; /// Sending data to public cloud or internet
	bool onboardingDutySlcRelevant; /// Onboarding-Duty / SLC relevant
	bool customerApprovalForUsage; /// Customer Approval for usage
	string customerContext; /// Customer Context
	string customerContextComment; /// Customer Context Comment
	double dataQualityIndex = 0; /// Data Quality Index
	int totalErrors; /// Total number of errors
	int totalWarnings; /// Total number of warnings
	int totalHints; /// Total number of hints
	string usage; /// Usage
	string targetUsage; /// Target Usage
	string usageEnvironment; /// Usage Environment
	string softwareOperationEnvironment; /// Software operation environment
	string userBase; /// User base within BWI
	string reasonForUsage; /// Reason for usage within BWI
	string requester; /// Requester
	string requesterComments; /// Requester Comments
	string productContact; /// Produktansprechpartner
	string serviceManager; /// Service Manager
	string technicalOrganizationId; /// Technisch verantwortliche Organisationseinheit
	string supportingCompany; /// Supporting Company
	string supportModel; /// Support Model
	bool manufacturerSupport; /// Manufacturer Support
}

struct ProductGroupRecord {
	mixin RecordFields;
	string capabilityId; /// Capability: IT Capability
	string levelId; /// Level ID
	string objectState = "Active"; /// Object State
	string parentGroupId; /// Parent Product Group
}

struct ApplicationGroupRecord {
	mixin RecordFields;
	string capabilityId; /// Capability: IT Capability
	string levelId; /// Level ID
	string objectState = "Active"; /// Object State
	string parentGroupId; /// Parent Application Group
	string stakeholder; /// Stakeholder
	// product totals are rolled up at read time and therefore not stored
}
