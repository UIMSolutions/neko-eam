/// DTOs of the analysis / reporting use cases.
module neko.eam.application.dtos.analysisdtos;

struct KindCountDto {
	string kind;
	size_t count;
}

struct TimeAssessmentDto {
	string applicationId;
	string applicationName;
	int businessValue;
	int technicalFit;
	string current;
	string recommended;
	bool deviates;
}

struct TechnologyRiskDto {
	string applicationId;
	string applicationName;
	string componentId;
	string componentName;
	string endOfSupportDate;
	string reason;
}

struct CapabilityCoverageDto {
	string capabilityId;
	string capabilityName;
	int level;
	string[] supportingApplicationIds;
	bool gap;
	bool redundant;
}

struct ImpactReportDto {
	string applicationId;
	string applicationName;
	string[] incomingFlowIds;
	string[] outgoingFlowIds;
	string[] dependentApplicationIds;
	string[] providingApplicationIds;
	string[] capabilityIds;
	string[] componentIds;
	string[] projectIds;
}

struct PortfolioReportDto {
	string generatedAt;
	KindCountDto[] counts;
	size_t operationalApplications;
	size_t missionCriticalApplications;
	double totalAnnualCost = 0;
	size_t capabilityGaps;
	size_t capabilityRedundancies;
	size_t technologyRiskCount;
	size_t timeDeviations;
	size_t[string] applicationsByTime;     /// TIME category -> count
	size_t[string] applicationsByStatus;   /// lifecycle status -> count
	TimeAssessmentDto[] timeAssessments;
	TechnologyRiskDto[] technologyRisks;
	size_t productAlertCount;
	size_t criticalProductAlerts;
	ProductAlertDto[] productAlerts;
}

struct ProductAlertDto {
	string productId;
	string productName;
	string productVersion;
	string kind;
	string date;
	string severity;
	string message;
	string[] applicationIds;
}

/// One hit of the central search.
struct SearchHitDto {
	string setName;      /// entity set (OData / navigation key)
	string typeLabel;    /// display label of the entity set
	string icon;         /// SAP icon name of the set
	string id;
	string name;
	string description;  /// shortened description
	string matchedField; /// label of the field that matched when it was not the name
	string snippet;      /// matched text around the hit
	int score;
}
