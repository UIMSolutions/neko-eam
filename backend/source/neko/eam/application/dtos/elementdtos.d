/// Data transfer objects of the architecture elements (enumerations are transported as names).
/// UDAs: domain constraints (@Required, @DateField, @References) and presentation metadata
/// (@Label, @Group, @ReadOnly, @ListColumn, @Multiline).
module neko.eam.application.dtos.elementdtos;

import neko.eam.domain.types : DateField, References, Required;
import neko.eam.application.dtos.annotations;

/// Common DTO fields.
mixin template ElementDtoFields() {
	@Label("ID") @Group("General") string id;
	@Required @Label("Name") @Group("General") @ListColumn string name;
	@Label("Description") @Group("General") @Multiline string description;
	@Label("Creation Date") @Group("Administration") @ReadOnly string createdAt;
	@Label("Creator") @Group("Administration") @ReadOnly string createdBy;
	@Label("Last Update") @Group("Administration") @ReadOnly string modifiedAt;
	@Label("Last Update User") @Group("Administration") @ReadOnly string modifiedBy;
}

struct ApplicationDto {
	mixin ElementDtoFields;
	@Label("Release") @Group("General") @ListColumn string release;
	@Label("Lifecycle Status") @Group("General") @ListColumn string status = "Active";
	@Label("Level ID") @Group("General") string levelId;
	@Label("Object State") @Group("General") string objectState = "Active";
	@References("ApplicationGroups") @Label("Parent Application Group") @Group("General") string applicationGroupId;
	@Label("Stakeholder") @Group("General") string stakeholder;
	@Label("Criticality") @Group("Assessment") @ListColumn string criticality = "Medium";
	@Label("TIME Category") @Group("Assessment") @ListColumn string timeCategory = "Tolerate";
	@Label("Business Value") @Group("Assessment") int businessValue = 3;
	@Label("Technical Fit") @Group("Assessment") int technicalFit = 3;
	@Label("Annual Cost") @Group("Assessment") double annualCost = 0;
	@DateField @Label("Go-Live Date") @Group("Lifecycle") string goLiveDate;
	@DateField @Label("Retirement Date") @Group("Lifecycle") string retirementDate;
	@References("Organizations") @Label("Owner Organization") @Group("Relations") string ownerOrganizationId;
	@References("BusinessCapabilities") @Label("Capability: IT Capability") @Group("Relations") string[] capabilityIds;
	@References("ITComponents") @Label("IT Components") @Group("Relations") string[] componentIds;
	@References("Products") @Label("Used Products") @Group("Products") string[] usedProductIds;
	@References("Products") @Label("Assigned Products") @Group("Products") string[] assignedProductIds;
	@Label("Insgesamt genutzte Produkte") @Group("Products") @ReadOnly @ListColumn int totalUsedProducts;
	@Label("Insgesamt zugewiesene Produkte") @Group("Products") @ReadOnly @ListColumn int totalAssignedProducts;
}

struct ApplicationGroupDto {
	mixin ElementDtoFields;
	@References("BusinessCapabilities") @Label("Capability: IT Capability") @Group("General") @ListColumn string capabilityId;
	@Label("Level ID") @Group("General") @ListColumn string levelId;
	@Label("Object State") @Group("General") @ListColumn string objectState = "Active";
	@References("ApplicationGroups") @Label("Parent Application Group") @Group("General") @ListColumn string parentGroupId;
	@Label("Stakeholder") @Group("General") @ListColumn string stakeholder;
	@Label("Insgesamt genutzte Produkte") @Group("Products") @ReadOnly @ListColumn int totalUsedProducts;
	@Label("Insgesamt zugewiesene Produkte") @Group("Products") @ReadOnly @ListColumn int totalAssignedProducts;
}

struct ProductDto {
	mixin ElementDtoFields;
	@References("ITComponents") @Label("Component") @Group("General") @ListColumn string componentId;
	@Label("Version") @Group("General") @ListColumn string productVersion;
	@Label("Major Version") @Group("General") string majorVersion;
	@Label("Version Type") @Group("General") string versionType = "Major";
	@Label("Product Edition") @Group("General") string productEdition;
	@References("ProductGroups") @Label("Product Group") @Group("General") @ListColumn string productGroupId;
	@Label("Product Type") @Group("General") string productType;
	@Label("Vendor") @Group("General") @ListColumn string vendor;
	@Label("Vendor Weblink") @Group("General") string vendorWeblink;
	@Label("Download link of the product version") @Group("General") string downloadLink;
	@Label("Status") @Group("General") string status = "Draft";
	@Label("Lifecycle Status") @Group("General") @ListColumn string lifecycleStatus = "Active";
	@Label("Approval Status") @Group("General") @ListColumn string approvalStatus = "Requested";
	@Label("Software Category") @Group("Classification") string softwareCategory;
	@Label("Softwareclass") @Group("Classification") string softwareClass;
	@Label("Standard Classification") @Group("Classification") string standardClassification;
	@Label("Maximo Classification Path") @Group("Classification") string maximoClassificationPath;
	@Label("Common Platform Enumeration-Kennung") @Group("Classification") string cpeId;
	@Label("CERTlich ID") @Group("Classification") string certlichId;
	@Label("PuLS ID") @Group("Classification") string pulsId;
	@Label("Source") @Group("Classification") string source;
	@Label("Appliance") @Group("Classification") bool appliance;
	@DateField @Label("Start Date") @Group("Lifecycle") string startDate;
	@DateField @Label("End Date") @Group("Lifecycle") string endDate;
	@DateField @Label("End of Support") @Group("Lifecycle") @ListColumn string endOfSupport;
	@DateField @Label("End of Security") @Group("Lifecycle") string endOfSecurity;
	@DateField @Label("End of Life") @Group("Lifecycle") string endOfLife;
	@DateField @Label("End of Support Contract") @Group("Lifecycle") string endOfSupportContract;
	@DateField @Label("Enddate BSI Permission") @Group("Lifecycle") string bsiPermissionEndDate;
	@DateField @Label("Due Date next Validation") @Group("Lifecycle") string dueDateNextValidation;
	@Label("Update Cycle in Weeks") @Group("Lifecycle") int updateCycleWeeks;
	@Label("Number of days before EOL reminder shall be send") @Group("Reminders") int eolReminderDays;
	@Label("Number of days before milestone reminder shall be send") @Group("Reminders") int milestoneReminderDays;
	@DateField @Label("Reminder EoL (Date)") @Group("Reminders") @ReadOnly string eolReminderDate;
	@Label("Reminder EoSu (in Days)") @Group("Reminders") int eosuReminderDays;
	@DateField @Label("Reminder EoSu (Date)") @Group("Reminders") @ReadOnly string eosuReminderDate;
	@Label("Licence Category") @Group("Licensing") string licenceCategory;
	@Label("Licensing Model") @Group("Licensing") string licensingModel;
	@Label("License costs") @Group("Licensing") double licenseCosts = 0;
	@Label("License owner") @Group("Licensing") string licenseOwner;
	@Label("Purchasable License required") @Group("Licensing") bool purchasableLicenseRequired;
	@Label("Number of Installations") @Group("Licensing") int numberOfInstallations;
	@Label("Modify OSS Sourcecode") @Group("Licensing") bool modifyOssSourcecode;
	@Label("IsBlacklisted") @Group("Security & Compliance") bool isBlacklisted;
	@Label("Risk Evaluation") @Group("Security & Compliance") string riskEvaluation = "Low";
	@Label("Protection") @Group("Security & Compliance") string protection = "Normal";
	@Label("Data Protection Requirements") @Group("Security & Compliance") string dataProtectionRequirements = "Normal";
	@Label("IPv6 Kommunikation") @Group("Security & Compliance") bool ipv6Communication;
	@Label("Sending data to public cloud or internet") @Group("Security & Compliance") bool sendsDataToPublicCloud;
	@Label("Onboarding-Duty / SLC relevant") @Group("Security & Compliance") bool onboardingDutySlcRelevant;
	@Label("Customer Approval for usage") @Group("Security & Compliance") bool customerApprovalForUsage;
	@Label("Customer Context") @Group("Security & Compliance") string customerContext;
	@Label("Customer Context Comment") @Group("Security & Compliance") @Multiline string customerContextComment;
	@Label("Data Quality Index") @Group("Data Quality") double dataQualityIndex = 0;
	@Label("Total number of errors") @Group("Data Quality") int totalErrors;
	@Label("Total number of warnings") @Group("Data Quality") int totalWarnings;
	@Label("Total number of hints") @Group("Data Quality") int totalHints;
	@Label("Usage") @Group("Usage") string usage;
	@Label("Target Usage") @Group("Usage") string targetUsage;
	@Label("Usage Environment") @Group("Usage") string usageEnvironment;
	@Label("Software operation environment") @Group("Usage") string softwareOperationEnvironment;
	@Label("User base within BWI") @Group("Usage") string userBase;
	@Label("Reason for usage within BWI") @Group("Usage") @Multiline string reasonForUsage;
	@Label("Requester") @Group("Responsibilities & Support") string requester;
	@Label("Requester Comments") @Group("Responsibilities & Support") @Multiline string requesterComments;
	@Label("Produktansprechpartner") @Group("Responsibilities & Support") string productContact;
	@Label("Service Manager") @Group("Responsibilities & Support") string serviceManager;
	@References("Organizations") @Label("Technisch verantwortliche Organisationseinheit") @Group("Responsibilities & Support") string technicalOrganizationId;
	@Label("Supporting Company") @Group("Responsibilities & Support") string supportingCompany;
	@Label("Support Model") @Group("Responsibilities & Support") string supportModel;
	@Label("Manufacturer Support") @Group("Responsibilities & Support") bool manufacturerSupport;
}

struct ProductGroupDto {
	mixin ElementDtoFields;
	@References("BusinessCapabilities") @Label("Capability: IT Capability") @Group("General") @ListColumn string capabilityId;
	@Label("Level ID") @Group("General") @ListColumn string levelId;
	@Label("Object State") @Group("General") @ListColumn string objectState = "Active";
	@References("ProductGroups") @Label("Parent Product Group") @Group("General") @ListColumn string parentGroupId;
}

struct BusinessCapabilityDto {
	mixin ElementDtoFields;
	@Label("Business Capability") @Group("General") @ReadOnly @ListColumn string hierarchyPath;
	@Label("Level ID") @Group("General") @ListColumn string levelId;
	@Label("Level ID Number") @Group("General") @ListColumn int level = 1;
	@Label("Mission Criticality") @Group("General") @ListColumn string missionCriticality = "Medium";
	@Label("Strategic Importance") @Group("General") int strategicImportance = 3;
	@Label("Stakeholder") @Group("General") string stakeholder;
	@References("BusinessCapabilities") @Label("Parent Business Capability") @Group("Relations") string parentId;
	@References("Organizations") @Label("Owner Organization") @Group("Relations") @ListColumn string ownerOrganizationId;
}

struct BusinessProcessDto {
	mixin ElementDtoFields;
	@Label("Business Process") @Group("General") @ReadOnly @ListColumn string hierarchyPath;
	@Label("Level ID") @Group("General") @ListColumn string levelId;
	@Label("Status") @Group("General") @ListColumn string status = "Active";
	@References("BusinessProcesses") @Label("Parent Business Process") @Group("General") string parentProcessId;
	@Label("Process Owner") @Group("Responsibilities") @ListColumn string processOwner;
	@Label("Process Manager") @Group("Responsibilities") @ListColumn string processManager;
}

struct BusinessDataDto {
	mixin ElementDtoFields;
	@Label("Version") @Group("General") @ListColumn string dataVersion;
	@Label("Business Object") @Group("General") @ListColumn string businessObject;
	@Label("DPIA Rating") @Group("General") @ListColumn string dpiaRating = "NotAssessed";
	@References("Organizations") @Label("Owner") @Group("General") @ListColumn string ownerOrganizationId;
	@References("BusinessCapabilities") @Label("Business Capability") @Group("Relations") @ListColumn string capabilityId;
	@References("InformationFlows") @Label("Information Flows") @Group("Relations") string[] informationFlowIds;
}

struct ServiceProductGroupDto {
	mixin ElementDtoFields;
	@Label("Catalog") @Group("General") @ReadOnly @ListColumn string hierarchyPath;
	@Label("Short Name") @Group("General") @ListColumn string shortName;
	@Label("Catalog Type") @Group("General") @ListColumn string catalogType = "BusinessService";
	@Label("Version") @Group("General") @ListColumn string catalogVersion;
	@Label("Status") @Group("General") @ListColumn string status = "Draft";
	@References("ServiceProductGroups") @Label("Parent Catalog") @Group("General") string parentId;
	@Label("Catalogue Manager") @Group("Release") @ListColumn string catalogueManager;
	@DateField @Label("Date of Release") @Group("Release") string releaseDate;
}

struct StrategicGuidelineDto {
	mixin ElementDtoFields;
	@Label("Strategic Guideline") @Group("General") @ReadOnly @ListColumn string hierarchyPath;
	@Label("Short Name") @Group("General") @ListColumn string shortName;
	@Label("Category") @Group("General") @ListColumn string category = "Architecture";
	@Label("Priority") @Group("General") @ListColumn string priority = "Medium";
	@Label("Status") @Group("General") @ListColumn string status = "Draft";
	@References("StrategicGuidelines") @Label("Parent Guideline") @Group("General") string parentId;
	@Label("Rationale") @Group("Statement") @Multiline string rationale;
	@Label("Implications") @Group("Statement") @Multiline string implications;
	@Label("Guideline Owner") @Group("Responsibilities") @ListColumn string guidelineOwner;
	@References("Organizations") @Label("Responsible Organization") @Group("Responsibilities") string ownerOrganizationId;
	@DateField @Label("Valid From") @Group("Validity") string validFrom;
	@DateField @Label("Valid Until") @Group("Validity") @ListColumn string validUntil;
	@References("BusinessCapabilities") @Label("Business Capabilities") @Group("Relations") string[] capabilityIds;
}

struct ServiceCapabilityDto {
	mixin ElementDtoFields;
	@Label("Service Capability") @Group("General") @ReadOnly @ListColumn string hierarchyPath;
	@Label("Short Name") @Group("General") @ListColumn string shortName;
	@Label("Level ID") @Group("General") @ListColumn string levelId;
	@Label("Status") @Group("General") @ListColumn string status = "Active";
	@Label("Mission Criticality") @Group("General") string missionCriticality = "Medium";
	@References("ServiceCapabilities") @Label("Parent Service Capability") @Group("General") string parentId;
	@Label("Current Maturity") @Group("Assessment") @ListColumn int currentMaturity = 1;
	@Label("Target Maturity") @Group("Assessment") @ListColumn int targetMaturity = 3;
	@Label("Maturity Gap") @Group("Assessment") @ReadOnly @ListColumn int maturityGap;
	@Label("Stakeholder") @Group("Responsibilities") string stakeholder;
	@References("Organizations") @Label("Responsible Organization") @Group("Responsibilities") string ownerOrganizationId;
	@References("BusinessCapabilities") @Label("Business Capability") @Group("Relations") string businessCapabilityId;
	@References("ServiceProductGroups") @Label("Service Catalogues") @Group("Relations") string[] serviceProductGroupIds;
	@References("Applications") @Label("Supporting Applications") @Group("Relations") string[] applicationIds;
}

struct MeasureGroupDto {
	mixin ElementDtoFields;
	@Label("Measure Group") @Group("General") @ReadOnly @ListColumn string hierarchyPath;
	@Label("Short Name") @Group("General") @ListColumn string shortName;
	@Label("Status") @Group("General") @ListColumn string status = "Draft";
	@References("MeasureGroups") @Label("Parent Measure Group") @Group("General") string parentGroupId;
	@Label("Responsible") @Group("Planning") @ListColumn string responsible;
	@References("Organizations") @Label("Responsible Organization") @Group("Planning") string ownerOrganizationId;
	@DateField @Label("Planning Period Start") @Group("Planning") string startDate;
	@DateField @Label("Planning Period End") @Group("Planning") string endDate;
	@Label("Budget") @Group("Planning") @ListColumn double budget = 0;
	@Label("Total Measures") @Group("Planning") @ReadOnly @ListColumn int totalMeasures;
	@Label("Total Estimated Cost") @Group("Planning") @ReadOnly @ListColumn double totalEstimatedCost = 0;
	@References("StrategicGuidelines") @Label("Strategic Guidelines") @Group("Relations") string[] strategicGuidelineIds;
}

struct MeasureDto {
	mixin ElementDtoFields;
	@Label("Short Name") @Group("General") string shortName;
	@References("MeasureGroups") @Label("Measure Group") @Group("General") @ListColumn string measureGroupId;
	@Label("Measure Type") @Group("General") @ListColumn string measureType = "Modernize";
	@Label("Priority") @Group("General") @ListColumn string priority = "Medium";
	@Label("Status") @Group("General") @ListColumn string status = "Draft";
	@Label("Progress (%)") @Group("General") @ListColumn int progress;
	@Label("Responsible") @Group("Planning") @ListColumn string responsible;
	@References("Organizations") @Label("Responsible Organization") @Group("Planning") string ownerOrganizationId;
	@DateField @Label("Start Date") @Group("Planning") string startDate;
	@DateField @Label("End Date") @Group("Planning") @ListColumn string endDate;
	@Label("Estimated Cost") @Group("Planning") double estimatedCost = 0;
	@Label("Expected Benefit") @Group("Planning") @Multiline string expectedBenefit;
	@References("Projects") @Label("Implementing Project") @Group("Planning") string projectId;
	@References("StrategicGuidelines") @Label("Strategic Guidelines") @Group("Relations") string[] strategicGuidelineIds;
	@References("ServiceCapabilities") @Label("Service Capabilities") @Group("Relations") string[] serviceCapabilityIds;
	@References("Applications") @Label("Affected Applications") @Group("Relations") string[] affectedApplicationIds;
	@References("ITComponents") @Label("Affected IT Components") @Group("Relations") string[] affectedComponentIds;
}

struct ArchitecturePrincipleDto {
	mixin ElementDtoFields;
	@Label("Short Name") @Group("General") @ListColumn string shortName;
	@Label("Architecture Domain") @Group("General") @ListColumn string domain = "Application";
	@Label("Priority") @Group("General") @ListColumn string priority = "Medium";
	@Label("Status") @Group("General") @ListColumn string status = "Draft";
	@Label("Version") @Group("General") string specVersion;
	@Label("Statement") @Group("Statement") @Multiline string statement;
	@Label("Rationale") @Group("Statement") @Multiline string rationale;
	@Label("Implications") @Group("Statement") @Multiline string implications;
	@Label("Principle Owner") @Group("Responsibilities") @ListColumn string principleOwner;
	@References("Organizations") @Label("Responsible Organization") @Group("Responsibilities") string ownerOrganizationId;
	@DateField @Label("Valid From") @Group("Validity") string validFrom;
	@DateField @Label("Valid Until") @Group("Validity") string validUntil;
	@References("StrategicGuidelines") @Label("Strategic Guidelines") @Group("Relations") string[] strategicGuidelineIds;
}

struct ArchitectureGuidelineDto {
	mixin ElementDtoFields;
	@Label("Short Name") @Group("General") @ListColumn string shortName;
	@Label("Architecture Domain") @Group("General") @ListColumn string domain = "Application";
	@Label("Obligation") @Group("General") @ListColumn string obligation = "Recommended";
	@Label("Status") @Group("General") @ListColumn string status = "Draft";
	@Label("Version") @Group("General") string specVersion;
	@Label("Applicability") @Group("Statement") @Multiline string applicability;
	@Label("Compliance Verification") @Group("Statement") @Multiline string verification;
	@Label("Guideline Owner") @Group("Responsibilities") @ListColumn string guidelineOwner;
	@References("Organizations") @Label("Responsible Organization") @Group("Responsibilities") string ownerOrganizationId;
	@DateField @Label("Valid From") @Group("Validity") string validFrom;
	@DateField @Label("Valid Until") @Group("Validity") string validUntil;
	@References("ArchitecturePrinciples") @Label("Architecture Principles") @Group("Relations") string[] principleIds;
	@References("Products") @Label("Standard Products") @Group("Relations") string[] standardProductIds;
	@References("ITComponents") @Label("IT Components") @Group("Relations") string[] componentIds;
}

struct ReferenceArchitectureDto {
	mixin ElementDtoFields;
	@Label("Reference Architecture") @Group("General") @ReadOnly @ListColumn string hierarchyPath;
	@Label("Short Name") @Group("General") @ListColumn string shortName;
	@Label("Architecture Domain") @Group("General") @ListColumn string domain = "Application";
	@Label("Status") @Group("General") @ListColumn string status = "Draft";
	@Label("Version") @Group("General") @ListColumn string specVersion;
	@References("ReferenceArchitectures") @Label("Parent Reference Architecture") @Group("General") string parentId;
	@Label("Scope") @Group("Statement") @Multiline string scopeDescription;
	@Label("Architect") @Group("Responsibilities") @ListColumn string architect;
	@References("Organizations") @Label("Responsible Organization") @Group("Responsibilities") string ownerOrganizationId;
	@DateField @Label("Valid From") @Group("Validity") string validFrom;
	@DateField @Label("Valid Until") @Group("Validity") string validUntil;
	@Label("Total Documents") @Group("Relations") @ReadOnly @ListColumn int totalDocuments;
	@References("ArchitecturePrinciples") @Label("Architecture Principles") @Group("Relations") string[] principleIds;
	@References("ArchitectureGuidelines") @Label("Architecture Guidelines") @Group("Relations") string[] guidelineIds;
	@References("BusinessCapabilities") @Label("Business Capabilities") @Group("Relations") string[] capabilityIds;
	@References("ITComponents") @Label("Building Blocks (IT Components)") @Group("Relations") string[] componentIds;
	@References("Products") @Label("Standard Products") @Group("Relations") string[] standardProductIds;
	@References("Applications") @Label("Implementing Applications") @Group("Relations") string[] applicationIds;
}

struct ArchitectureDocumentDto {
	mixin ElementDtoFields;
	@Label("Document Number") @Group("General") @ListColumn string documentNumber;
	@Label("Document Type") @Group("General") @ListColumn string documentType = "Concept";
	@Label("Status") @Group("General") @ListColumn string status = "Draft";
	@Label("Version") @Group("General") @ListColumn string docVersion;
	@Label("Confidentiality") @Group("General") string confidentiality = "Internal";
	@Label("Document Link") @Group("General") string documentLink;
	@Label("Author") @Group("Release") @ListColumn string author;
	@Label("Approver") @Group("Release") string approver;
	@DateField @Label("Approval Date") @Group("Release") string approvalDate;
	@DateField @Label("Next Review Date") @Group("Release") @ListColumn string nextReviewDate;
	@Label("Review Overdue") @Group("Release") @ReadOnly @ListColumn bool reviewOverdue;
	@References("Organizations") @Label("Responsible Organization") @Group("Release") string ownerOrganizationId;
	@References("ReferenceArchitectures") @Label("Reference Architectures") @Group("Relations") string[] referenceArchitectureIds;
	@References("ArchitecturePrinciples") @Label("Architecture Principles") @Group("Relations") string[] principleIds;
	@References("ArchitectureGuidelines") @Label("Architecture Guidelines") @Group("Relations") string[] guidelineIds;
	@References("Applications") @Label("Applications") @Group("Relations") string[] applicationIds;
}

struct UserDto {
	mixin ElementDtoFields;
	@Required @Label("User Name") @Group("General") @ListColumn string userName;
	@Label("E-Mail") @Group("General") @ListColumn string email;
	@Label("Active") @Group("General") @ListColumn bool active = true;
	@DateField @Label("Valid Until") @Group("General") string validUntil;
	@References("Organizations") @Label("Organization") @Group("General") @ListColumn string organizationId;
	@References("Roles") @Label("Roles") @Group("Access") @ListColumn string[] roleIds;
	@Label("Effective Rights") @Group("Access") @ReadOnly @Multiline string effectiveRights;
}

struct RoleDto {
	mixin ElementDtoFields;
	@Label("Role Key") @Group("General") @ListColumn string roleKey;
	@Label("Status") @Group("General") @ListColumn string status = "Active";
	@Label("Total Users") @Group("General") @ReadOnly @ListColumn int totalUsers;
	@References("Permissions") @Label("Permissions") @Group("Access") @ListColumn string[] permissionIds;
}

struct PermissionDto {
	mixin ElementDtoFields;
	@Label("Entity Set") @Group("General") @ListColumn string entitySet = "All";
	@Label("Read") @Group("Access") @ListColumn bool canRead = true;
	@Label("Create") @Group("Access") @ListColumn bool canCreate;
	@Label("Update") @Group("Access") @ListColumn bool canUpdate;
	@Label("Delete") @Group("Access") @ListColumn bool canDelete;
	@Label("Total Roles") @Group("General") @ReadOnly @ListColumn int totalRoles;
}

struct ITProcessDto {
	mixin ElementDtoFields;
	@Label("IT Process") @Group("General") @ReadOnly @ListColumn string hierarchyPath;
	@Label("Short Name") @Group("General") @ListColumn string shortName;
	@Label("Level ID") @Group("General") string levelId;
	@Label("Framework") @Group("General") @ListColumn string framework = "ITIL4";
	@Label("Status") @Group("General") @ListColumn string status = "Active";
	@Label("Purpose") @Group("General") @Multiline string purpose;
	@References("ITProcesses") @Label("Parent IT Process") @Group("General") string parentProcessId;
	@Label("Process Owner") @Group("Responsibilities") @ListColumn string processOwner;
	@Label("Process Manager") @Group("Responsibilities") string processManager;
	@References("Organizations") @Label("Responsible Organization") @Group("Responsibilities") string ownerOrganizationId;
	@Label("Current Maturity") @Group("Assessment") int currentMaturity = 1;
	@Label("Target Maturity") @Group("Assessment") int targetMaturity = 3;
	@Label("Steps") @Group("Assessment") @ReadOnly @ListColumn int totalSteps;
	@Label("KPI Status") @Group("Assessment") @ReadOnly @ListColumn string kpiStatus = "NoData";
	@References("BusinessProcesses") @Label("Supported Business Processes") @Group("Relations") string[] businessProcessIds;
	@References("ServiceProductGroups") @Label("Services") @Group("Relations") string[] serviceProductGroupIds;
}

struct ProcessStepDto {
	mixin ElementDtoFields;
	@Required @References("ITProcesses") @Label("IT Process") @Group("General") @ListColumn string processId;
	@Label("Sequence No.") @Group("General") @ListColumn int sequenceNo = 10;
	@Label("Step Type") @Group("General") @ListColumn string stepType = "Activity";
	@Label("Automation Level") @Group("General") @ListColumn string automationLevel = "Manual";
	@Label("Performer Role") @Group("Responsibilities") @ListColumn string performerRole;
	@References("Organizations") @Label("Responsible Organization") @Group("Responsibilities") string responsibleOrganizationId;
	@Label("Duration (hours)") @Group("Planning") double durationHours = 0;
	@Label("Inputs") @Group("Planning") @Multiline string inputs;
	@Label("Outputs") @Group("Planning") @Multiline string outputs;
	@References("Applications") @Label("Supporting Applications") @Group("Relations") @ListColumn string[] applicationIds;
}

struct ProcessKpiDto {
	mixin ElementDtoFields;
	@Required @References("ITProcesses") @Label("IT Process") @Group("General") @ListColumn string processId;
	@Label("Unit") @Group("General") @ListColumn string unit;
	@Label("Direction") @Group("General") string direction = "HigherIsBetter";
	@Label("KPI Owner") @Group("General") string kpiOwner;
	@Label("Measurement Frequency") @Group("General") string frequency;
	@Label("Target Value") @Group("Measurement") @ListColumn double targetValue = 0;
	@Label("Threshold") @Group("Measurement") double thresholdValue = 0;
	@Label("Actual Value") @Group("Measurement") @ListColumn double actualValue = 0;
	@Label("Measured") @Group("Measurement") bool measured;
	@DateField @Label("Measured At") @Group("Measurement") @ListColumn string measuredAt;
	@Label("Status") @Group("Measurement") @ReadOnly @ListColumn string kpiStatus = "NoData";
	@Label("Achievement (%)") @Group("Measurement") @ReadOnly double achievement = 0;
}

struct ProtectionRequirementDto {
	mixin ElementDtoFields;
	@References("Applications") @Label("Application") @Group("General") @ListColumn string applicationId;
	@References("BusinessData") @Label("Business Data") @Group("General") @ListColumn string businessDataId;
	@References("ITComponents") @Label("IT Component") @Group("General") string componentId;
	@Label("Status") @Group("General") @ListColumn string status = "Draft";
	@Label("Confidentiality") @Group("Assessment") @ListColumn string confidentiality = "Normal";
	@Label("Integrity") @Group("Assessment") @ListColumn string integrity = "Normal";
	@Label("Availability") @Group("Assessment") @ListColumn string availability = "Normal";
	@Label("Overall Protection Level") @Group("Assessment") @ReadOnly @ListColumn string overallLevel = "Normal";
	@Label("Justification") @Group("Assessment") @Multiline string justification;
	@Label("Assessed By") @Group("Validity") string assessedBy;
	@DateField @Label("Assessment Date") @Group("Validity") string assessmentDate;
	@DateField @Label("Next Review Date") @Group("Validity") string nextReviewDate;
	@Label("Review Overdue") @Group("Validity") @ReadOnly @ListColumn bool reviewOverdue;
}

struct SecurityRiskDto {
	mixin ElementDtoFields;
	@Label("Risk Number") @Group("General") @ListColumn string riskNumber;
	@Label("Status") @Group("General") @ListColumn string status = "Identified";
	@Label("Threat") @Group("General") @Multiline string threat;
	@Label("Vulnerability") @Group("General") @Multiline string vulnerability;
	@Label("Likelihood") @Group("Assessment") int likelihood = 3;
	@Label("Impact") @Group("Assessment") int impact = 3;
	@Label("Risk Score") @Group("Assessment") @ReadOnly @ListColumn int riskScore;
	@Label("Risk Level") @Group("Assessment") @ReadOnly @ListColumn string riskLevel = "Low";
	@Label("Treatment") @Group("Treatment") @ListColumn string treatment = "Mitigate";
	@Label("Risk Owner") @Group("Treatment") @ListColumn string riskOwner;
	@DateField @Label("Due Date") @Group("Treatment") string dueDate;
	@Label("Residual Likelihood") @Group("Treatment") int residualLikelihood;
	@Label("Residual Impact") @Group("Treatment") int residualImpact;
	@Label("Residual Score") @Group("Treatment") @ReadOnly int residualScore;
	@Label("Residual Level") @Group("Treatment") @ReadOnly @ListColumn string residualLevel = "Low";
	@References("SecurityControls") @Label("Controls") @Group("Relations") string[] controlIds;
	@References("Applications") @Label("Affected Applications") @Group("Relations") string[] applicationIds;
	@References("ITComponents") @Label("Affected IT Components") @Group("Relations") string[] componentIds;
	@References("BusinessData") @Label("Affected Business Data") @Group("Relations") string[] businessDataIds;
}

struct SecurityControlDto {
	mixin ElementDtoFields;
	@Label("Control Reference") @Group("General") @ListColumn string controlReference;
	@Label("Framework") @Group("General") @ListColumn string framework = "ISO27001";
	@Label("Control Type") @Group("General") string controlType = "Preventive";
	@Label("Implementation Status") @Group("General") @ListColumn string implementationStatus = "Planned";
	@Label("Effectiveness") @Group("Assessment") int effectiveness;
	@Label("Mitigated Risks") @Group("Assessment") @ReadOnly @ListColumn int mitigatedRisks;
	@Label("Control Owner") @Group("Responsibilities") @ListColumn string controlOwner;
	@DateField @Label("Due Date") @Group("Responsibilities") @ListColumn string dueDate;
	@DateField @Label("Last Review") @Group("Responsibilities") string lastReviewDate;
	@Label("Overdue") @Group("Responsibilities") @ReadOnly @ListColumn bool overdue;
	@References("Applications") @Label("Applications") @Group("Relations") string[] applicationIds;
	@References("ITComponents") @Label("IT Components") @Group("Relations") string[] componentIds;
}

struct ReportDto {
	mixin ElementDtoFields;
	@Label("Category") @Group("General") @ListColumn string category;
	@Label("Entity Set") @Group("General") @ListColumn string entitySet = "Applications";
	@Label("Report Owner") @Group("General") @ListColumn string reportOwner;
	@Label("Columns") @Group("Query") string[] columns;
	@Label("Filter") @Group("Query") @Multiline string filter;
	@Label("Order By") @Group("Query") string orderBy;
	@Label("Group By") @Group("Query") string groupBy;
	@Label("Sum Field") @Group("Query") string sumField;
	@Label("Max Rows") @Group("Query") int maxRows;
}

struct ReportBookDto {
	mixin ElementDtoFields;
	@Label("Audience") @Group("General") @ListColumn string audience;
	@Label("Report Owner") @Group("General") @ListColumn string reportOwner;
	@References("Reports") @Label("Reports") @Group("General") @ListColumn string[] reportIds;
}

struct ITComponentDto {
	mixin ElementDtoFields;
	@Label("Vendor") @Group("General") @ListColumn string vendor;
	@Label("Release") @Group("General") @ListColumn string release;
	@Label("Category") @Group("General") @ListColumn string category = "Software";
	@Label("Lifecycle Status") @Group("General") @ListColumn string status = "Active";
	@DateField @Label("End of Support") @Group("Lifecycle") @ListColumn string endOfSupportDate;
	@Label("License Cost") @Group("Lifecycle") double licenseCost = 0;
}

struct InformationFlowDto {
	mixin ElementDtoFields;
	@Required @References("Applications") @Label("Source Application") @Group("General") @ListColumn string sourceApplicationId;
	@Required @References("Applications") @Label("Target Application") @Group("General") @ListColumn string targetApplicationId;
	@Label("Interface Type") @Group("General") @ListColumn string flowType = "Api";
	@Label("Data Object") @Group("General") @ListColumn string dataObject;
	@Label("Frequency") @Group("General") @ListColumn string frequency;
}

struct OrganizationDto {
	mixin ElementDtoFields;
	@Label("Organisation") @Group("General") @ReadOnly @ListColumn string hierarchyPath;
	@Label("Short Name") @Group("General") @ListColumn string shortName;
	@Label("Status") @Group("General") @ListColumn string status = "Active";
	@Label("Organization Type") @Group("General") @ListColumn string orgType = "Department";
	@Label("Location") @Group("General") string location;
	@References("Organizations") @Label("Parent Organization") @Group("General") string parentId;
	@DateField @Label("Start Date") @Group("General") string startDate;
	@DateField @Label("End Date") @Group("General") string endDate;
	@Label("Architect") @Group("Responsibilities") @ListColumn string architect;
	@Label("Contact") @Group("Responsibilities") string contact;
	@Label("Stakeholder") @Group("Responsibilities") string stakeholder;
	@Label("Total Consumed Business Services") @Group("Services") int totalConsumedBusinessServices;
	@Label("Total Provided Business Services") @Group("Services") int totalProvidedBusinessServices;
	@Label("Total Provided Support Services") @Group("Services") int totalProvidedSupportServices;
	@References("Enterprises") @Label("Legal Entity") @Group("Staffing") @ListColumn string enterpriseId;
	@Label("Cost Center") @Group("Staffing") string costCenter;
	@Label("Head of Unit") @Group("Staffing") @ReadOnly @ListColumn string headOfUnit;
	@Label("Members") @Group("Staffing") @ReadOnly @ListColumn int totalMembers;
	@Label("Capacity (FTE)") @Group("Staffing") @ReadOnly double totalCapacity = 0;
}

struct EnterpriseDto {
	mixin ElementDtoFields;
	@Label("Organisation") @Group("General") @ReadOnly @ListColumn string hierarchyPath;
	@Label("Short Name") @Group("General") @ListColumn string shortName;
	@Label("Legal Form") @Group("General") @ListColumn string legalForm;
	@Label("Status") @Group("General") @ListColumn string status = "Active";
	@Label("Industry") @Group("General") string industry;
	@Label("Website") @Group("General") string website;
	@DateField @Label("Founding Date") @Group("General") string foundingDate;
	@Label("Commercial Register Number") @Group("Legal") string registrationNumber;
	@Label("VAT ID") @Group("Legal") string vatId;
	@Label("Headquarters") @Group("Legal") @ListColumn string headquarters;
	@Label("Country") @Group("Legal") @ListColumn string country;
	@References("Enterprises") @Label("Parent Organisation") @Group("Group Structure") string parentEnterpriseId;
	@Label("Ownership Share (%)") @Group("Group Structure") double ownershipShare = 0;
	@Label("Managing Director") @Group("Group Structure") @ReadOnly @ListColumn string managingDirector;
	@Label("Organisational Units") @Group("Staffing") @ReadOnly @ListColumn int totalUnits;
	@Label("Members") @Group("Staffing") @ReadOnly @ListColumn int totalMembers;
}

struct MemberDto {
	mixin ElementDtoFields;
	@Label("Personnel Number") @Group("General") @ListColumn string personnelNumber;
	@Label("Job Title") @Group("General") @ListColumn string jobTitle;
	@Required @References("Organizations") @Label("Organisational Unit") @Group("General") @ListColumn string organizationId;
	@Label("Function") @Group("General") @ListColumn string memberFunction = "Employee";
	@Label("Employment Type") @Group("General") string employmentType = "Internal";
	@Label("Capacity (%)") @Group("General") @ListColumn int capacity = 100;
	@Label("Current") @Group("General") @ReadOnly @ListColumn bool current;
	@Label("E-Mail") @Group("Contact") string email;
	@Label("Phone") @Group("Contact") string phone;
	@Label("Location") @Group("Contact") string location;
	@DateField @Label("Start Date") @Group("Staffing") string startDate;
	@DateField @Label("End Date") @Group("Staffing") string endDate;
	@References("Members") @Label("Line Manager") @Group("Staffing") string managerId;
	@References("Users") @Label("User Account") @Group("Staffing") string userId;
}

struct ProjectDto {
	mixin ElementDtoFields;
	@Label("Project Number") @Group("General") @ListColumn string projectNumber;
	@Label("Project Status") @Group("General") @ListColumn string status = "Proposed";
	@Label("Phase") @Group("General") @ListColumn string phase = "Initiation";
	@Label("Priority") @Group("General") string priority = "Medium";
	@Label("Project Manager") @Group("Planning") @ListColumn string projectManager;
	@DateField @Label("Start Date") @Group("Planning") @ListColumn string startDate;
	@DateField @Label("End Date") @Group("Planning") @ListColumn string endDate;
	@Label("Budget") @Group("Planning") @ListColumn double budget = 0;
	@Label("Actual Cost") @Group("Planning") double actualCost = 0;
	@Label("Total Sub Projects") @Group("Progress") @ReadOnly int totalSubProjects;
	@Label("Total Work Packages") @Group("Progress") @ReadOnly int totalWorkPackages;
	@Label("Planned Effort (days)") @Group("Progress") @ReadOnly double plannedEffortDays = 0;
	@Label("Progress (%)") @Group("Progress") @ReadOnly @ListColumn int progress;
	@References("Organizations") @Label("Sponsor") @Group("Relations") string sponsorOrganizationId;
	@References("Applications") @Label("Affected Applications") @Group("Relations") string[] affectedApplicationIds;
}

struct SubProjectDto {
	mixin ElementDtoFields;
	@Label("Sub Project") @Group("General") @ReadOnly @ListColumn string hierarchyPath;
	@Label("Short Name") @Group("General") string shortName;
	@Required @References("Projects") @Label("Project") @Group("General") @ListColumn string projectId;
	@References("SubProjects") @Label("Parent Sub Project") @Group("General") string parentSubProjectId;
	@Label("Status") @Group("General") @ListColumn string status = "Proposed";
	@Label("Sub Project Manager") @Group("Planning") @ListColumn string subProjectManager;
	@DateField @Label("Start Date") @Group("Planning") string startDate;
	@DateField @Label("End Date") @Group("Planning") @ListColumn string endDate;
	@Label("Budget") @Group("Planning") double budget = 0;
	@References("Organizations") @Label("Responsible Organization") @Group("Planning") string ownerOrganizationId;
	@Label("Total Work Packages") @Group("Progress") @ReadOnly int totalWorkPackages;
	@Label("Planned Effort (days)") @Group("Progress") @ReadOnly double plannedEffortDays = 0;
	@Label("Progress (%)") @Group("Progress") @ReadOnly @ListColumn int progress;
	@References("Applications") @Label("Affected Applications") @Group("Relations") string[] affectedApplicationIds;
}

struct WorkPackageDto {
	mixin ElementDtoFields;
	@Label("WBS Code") @Group("General") @ListColumn string wbsCode;
	@Required @References("Projects") @Label("Project") @Group("General") @ListColumn string projectId;
	@References("SubProjects") @Label("Sub Project") @Group("General") @ListColumn string subProjectId;
	@Label("Status") @Group("General") @ListColumn string status = "NotStarted";
	@Label("Responsible") @Group("Planning") @ListColumn string responsible;
	@DateField @Label("Start Date") @Group("Planning") string startDate;
	@DateField @Label("End Date") @Group("Planning") @ListColumn string endDate;
	@Label("Planned Effort (days)") @Group("Planning") double plannedEffortDays = 0;
	@Label("Actual Effort (days)") @Group("Planning") double actualEffortDays = 0;
	@Label("Planned Cost") @Group("Planning") double plannedCost = 0;
	@Label("Actual Cost") @Group("Planning") double actualCost = 0;
	@Label("Deliverables") @Group("Planning") @Multiline string deliverables;
	@Label("Progress (%)") @Group("Progress") @ListColumn int progress;
	@Label("Delayed") @Group("Progress") @ReadOnly @ListColumn bool delayed;
	@References("WorkPackages") @Label("Predecessors") @Group("Relations") string[] predecessorIds;
	@References("Measures") @Label("Implemented Measures") @Group("Relations") string[] measureIds;
	@References("Applications") @Label("Affected Applications") @Group("Relations") string[] affectedApplicationIds;
}
