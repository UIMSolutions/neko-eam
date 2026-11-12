/// Security risk (ISO 27005): threat and vulnerability, likelihood x impact (1-5) = score / level,
/// treatment, controls and residual risk.
module neko.eam.domain.entities.securityrisk;

import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class SecurityRisk {
	mixin ArchitectureElementFields;

	string riskNumber;                /// Risk Number
	string threat;                    /// Threat
	string vulnerability;             /// Vulnerability
	int likelihood = 3;               /// Likelihood (1-5)
	int impact = 3;                   /// Impact (1-5)
	int residualLikelihood;           /// Residual Likelihood (1-5, 0 = not assessed)
	int residualImpact;               /// Residual Impact (1-5, 0 = not assessed)
	RiskTreatment treatment = RiskTreatment.Mitigate; /// Treatment
	RiskStatus status = RiskStatus.Identified; /// Status
	string riskOwner;                 /// Risk Owner
	@DateField string dueDate;        /// Due Date
	@References("Applications") string[] applicationIds;   /// Affected Applications
	@References("ITComponents") string[] componentIds;     /// Affected IT Components
	@References("BusinessData") string[] businessDataIds;  /// Affected Business Data
	@References("SecurityControls") string[] controlIds;   /// Controls
	// derived
	int riskScore;                    /// Risk Score (likelihood x impact)
	RiskLevel riskLevel = RiskLevel.Low; /// Risk Level
	int residualScore;                /// Residual Score
	RiskLevel residualLevel = RiskLevel.Low; /// Residual Level

	/// Score 1-4 Low, 5-9 Medium, 10-16 High, 17-25 Critical.
	static RiskLevel levelOf(int score) pure @safe {
		return score >= 17 ? RiskLevel.Critical : score >= 10 ? RiskLevel.High : score >= 5 ? RiskLevel.Medium : RiskLevel.Low;
	}

	void derive() {
		riskScore = likelihood * impact;
		riskLevel = levelOf(riskScore);
		immutable assessed = residualLikelihood > 0 && residualImpact > 0;
		residualScore = assessed ? residualLikelihood * residualImpact : riskScore;
		residualLevel = levelOf(residualScore);
	}

	void validate() const {
		validateAnnotatedFields(this);
		checkRange("likelihood", likelihood, 1, 5);
		checkRange("impact", impact, 1, 5);
		checkRange("residualLikelihood", residualLikelihood, 0, 5);
		checkRange("residualImpact", residualImpact, 0, 5);
		if (residualScore > riskScore)
			throw new ValidationException("residualLikelihood", "The residual risk cannot be higher than the risk itself");
		if (status == RiskStatus.Accepted) {
			if (treatment != RiskTreatment.Accept)
				throw new ValidationException("treatment", "Only risks with treatment 'Accept' can be accepted");
			if (riskOwner.length == 0)
				throw new ValidationException("riskOwner", "An accepted risk needs a risk owner");
			if (residualLevel == RiskLevel.Critical)
				throw new ValidationException("status", "A critical (residual) risk cannot be accepted");
		}
		if (treatment == RiskTreatment.Mitigate && (status == RiskStatus.InTreatment || status == RiskStatus.Closed)
				&& controlIds.length == 0)
			throw new ValidationException("controlIds", "A mitigated risk needs at least one control");
	}
}

unittest {
	auto r = new SecurityRisk;
	r.name = "Ransomware"; r.likelihood = 4; r.impact = 5;
	r.derive();
	assert(r.riskScore == 20 && r.riskLevel == RiskLevel.Critical);
	r.treatment = RiskTreatment.Accept; r.status = RiskStatus.Accepted; r.riskOwner = "CISO";
	bool failed;
	try r.validate(); catch (ValidationException e) failed = e.field == "status";
	assert(failed, "critical risks are not accepted");
	r.residualLikelihood = 2; r.residualImpact = 4;
	r.derive();
	r.validate();
	assert(r.residualLevel == RiskLevel.Medium);
}
