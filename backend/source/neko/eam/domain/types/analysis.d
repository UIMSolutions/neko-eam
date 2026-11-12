/// Result value objects produced by domain services.
module neko.eam.domain.types.analysis;

import neko.eam.domain.enumerations;

/// TIME assessment of a single application.
struct TimeAssessment {
	string applicationId;
	string applicationName;
	int businessValue;
	int technicalFit;
	TimeCategory current;
	TimeCategory recommended;
	bool deviates; /// current classification differs from recommendation
}

/// An application depending on an outdated technology.
struct TechnologyRisk {
	string applicationId;
	string applicationName;
	string componentId;
	string componentName;
	string endOfSupportDate;
	string reason;
}

/// How well a business capability is supported by active applications.
struct CapabilityCoverage {
	string capabilityId;
	string capabilityName;
	int level;
	string[] supportingApplicationIds;
	bool gap;        /// no active application supports this capability
	bool redundant;  /// more than one active application supports it
}

/// Dependencies of an application (impact analysis).
struct Impact {
	string applicationId;
	string applicationName;
	string[] incomingFlowIds;
	string[] outgoingFlowIds;
	string[] dependentApplicationIds;   /// consumers of outgoing data
	string[] providingApplicationIds;   /// providers of incoming data
	string[] capabilityIds;
	string[] componentIds;
	string[] projectIds;
}

/// A lifecycle / compliance finding on a product of the catalogue.
struct ProductAlert {
	string productId;
	string productName;
	string productVersion;
	ProductAlertKind kind;
	string date;                 /// milestone date the alert refers to (may be empty)
	RiskLevel severity;
	string message;
	string[] applicationIds;     /// operational applications using / assigned to the product
}
