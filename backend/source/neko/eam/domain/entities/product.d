/// Product (software product version) of the IT product catalogue - the technology standard
/// that applications use. Carries lifecycle milestones, licensing, compliance and quality data.
module neko.eam.domain.entities.product;

import std.algorithm : startsWith;
import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class Product {
	mixin ArchitectureElementFields;

	@References("ITComponents") string componentId; /// Component
	string productVersion; /// Version
	string majorVersion; /// Major Version
	VersionType versionType = VersionType.Major; /// Version Type
	string productEdition; /// Product Edition
	@References("ProductGroups") string productGroupId; /// Product Group
	string productType; /// Product Type
	string vendor; /// Vendor
	string vendorWeblink; /// Vendor Weblink
	string downloadLink; /// Download link of the product version
	ProductStatus status = ProductStatus.Draft; /// Status
	LifecycleStatus lifecycleStatus = LifecycleStatus.Active; /// Lifecycle Status
	ApprovalStatus approvalStatus = ApprovalStatus.Requested; /// Approval Status
	string softwareCategory; /// Software Category
	string softwareClass; /// Softwareclass
	string standardClassification; /// Standard Classification
	string maximoClassificationPath; /// Maximo Classification Path
	string cpeId; /// Common Platform Enumeration-Kennung
	string certlichId; /// CERTlich ID
	string pulsId; /// PuLS ID
	string source; /// Source
	bool appliance; /// Appliance
	@DateField string startDate; /// Start Date
	@DateField string endDate; /// End Date
	@DateField string endOfSupport; /// End of Support
	@DateField string endOfSecurity; /// End of Security
	@DateField string endOfLife; /// End of Life
	@DateField string endOfSupportContract; /// End of Support Contract
	@DateField string bsiPermissionEndDate; /// Enddate BSI Permission
	@DateField string dueDateNextValidation; /// Due Date next Validation
	int updateCycleWeeks; /// Update Cycle in Weeks
	int eolReminderDays; /// Number of days before EOL reminder shall be send
	int milestoneReminderDays; /// Number of days before milestone reminder shall be send
	@DateField string eolReminderDate; /// Reminder EoL (Date)
	int eosuReminderDays; /// Reminder EoSu (in Days)
	@DateField string eosuReminderDate; /// Reminder EoSu (Date)
	string licenceCategory; /// Licence Category
	string licensingModel; /// Licensing Model
	double licenseCosts = 0; /// License costs
	string licenseOwner; /// License owner
	bool purchasableLicenseRequired; /// Purchasable License required
	int numberOfInstallations; /// Number of Installations
	bool modifyOssSourcecode; /// Modify OSS Sourcecode
	bool isBlacklisted; /// IsBlacklisted
	RiskLevel riskEvaluation = RiskLevel.Low; /// Risk Evaluation
	ProtectionLevel protection = ProtectionLevel.Normal; /// Protection
	ProtectionLevel dataProtectionRequirements = ProtectionLevel.Normal; /// Data Protection Requirements
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
	@References("Organizations") string technicalOrganizationId; /// Technisch verantwortliche Organisationseinheit
	string supportingCompany; /// Supporting Company
	string supportModel; /// Support Model
	bool manufacturerSupport; /// Manufacturer Support

	/// Derived values: reminder dates are computed from the milestone and the lead time in days.
	void derive() @safe {
		eolReminderDate = endOfLife.length && eolReminderDays > 0 ? addDays(endOfLife, -eolReminderDays) : "";
		eosuReminderDate = endOfSupport.length && eosuReminderDays > 0 ? addDays(endOfSupport, -eosuReminderDays) : "";
	}

	/// true while the product may be used productively.
	bool isUsable() const @safe pure nothrow {
		return !isBlacklisted && lifecycleStatus != LifecycleStatus.Retired && status != ProductStatus.Withdrawn;
	}

	void validate() const {
		validateAnnotatedFields(this);
		checkDateOrder("startDate", startDate, "endDate", endDate);
		static foreach (f; ["updateCycleWeeks", "numberOfInstallations", "totalErrors", "totalWarnings", "totalHints"])
			checkRange(f, __traits(getMember, this, f), 0, int.max);
		static foreach (f; ["eolReminderDays", "milestoneReminderDays", "eosuReminderDays"])
			checkRange(f, __traits(getMember, this, f), 0, 3650);
		if (licenseCosts < 0)
			throw new ValidationException("licenseCosts", "licenseCosts must not be negative");
		if (dataQualityIndex < 0 || dataQualityIndex > 100)
			throw new ValidationException("dataQualityIndex", "dataQualityIndex must be between 0 and 100");
		static foreach (f; ["vendorWeblink", "downloadLink"]) {{
			auto url = __traits(getMember, this, f);
			if (url.length && !url.startsWith("http://") && !url.startsWith("https://"))
				throw new ValidationException(f, "Field '" ~ f ~ "' must be an http(s) URL");
		}}
		if (isBlacklisted && (approvalStatus == ApprovalStatus.Approved || approvalStatus == ApprovalStatus.ApprovedWithConditions))
			throw new ValidationException("approvalStatus", "A blacklisted product cannot be approved");
	}
}

unittest {
	auto p = new Product;
	p.name = "PostgreSQL";
	p.endOfLife = "2027-11-11";
	p.eolReminderDays = 30;
	p.derive();
	assert(p.eolReminderDate == "2027-10-12" && p.eosuReminderDate == "");
	p.validate();
	p.isBlacklisted = true;
	p.approvalStatus = ApprovalStatus.Approved;
	bool failed;
	try p.validate(); catch (ValidationException e) failed = e.field == "approvalStatus";
	assert(failed);
	p.approvalStatus = ApprovalStatus.Rejected;
	p.vendorWeblink = "ftp://x";
	failed = false;
	try p.validate(); catch (ValidationException e) failed = e.field == "vendorWeblink";
	assert(failed && !p.isUsable);
}
