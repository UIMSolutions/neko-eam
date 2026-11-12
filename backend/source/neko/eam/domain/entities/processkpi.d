/// Process KPI - key performance indicator of an IT process with target, threshold and measured value.
/// The status (on track / at risk / off track) and the achievement are derived.
module neko.eam.domain.entities.processkpi;

import std.math : abs;
import neko.eam.domain.types;
import neko.eam.domain.enumerations;
import neko.eam.domain.exceptions;
import neko.eam.domain.entities.validation;

final class ProcessKpi {
	mixin ArchitectureElementFields;

	@Required @References("ITProcesses") string processId; /// IT Process
	string unit;                      /// Unit (e.g. %, h, count)
	KpiDirection direction = KpiDirection.HigherIsBetter; /// Direction
	double targetValue = 0;           /// Target Value
	double thresholdValue = 0;        /// Threshold (at risk beyond target, off track beyond threshold)
	double actualValue = 0;           /// Actual Value
	bool measured;                    /// Measured (an actual value is available)
	@DateField string measuredAt;     /// Measured At
	string frequency;                 /// Measurement Frequency
	string kpiOwner;                  /// KPI Owner
	KpiStatus kpiStatus = KpiStatus.NoData; /// Status (derived)
	double achievement = 0;           /// Achievement (%) (derived)

	/// OnTrack when the target is met, AtRisk up to the threshold, OffTrack beyond it.
	static KpiStatus evaluate(KpiDirection d, double target, double threshold, double actual, bool measured) pure @safe {
		if (!measured) return KpiStatus.NoData;
		immutable better = d == KpiDirection.HigherIsBetter;
		if (better ? actual >= target : actual <= target) return KpiStatus.OnTrack;
		if (better ? actual >= threshold : actual <= threshold) return KpiStatus.AtRisk;
		return KpiStatus.OffTrack;
	}

	void derive() {
		kpiStatus = evaluate(direction, targetValue, thresholdValue, actualValue, measured);
		if (!measured || targetValue == 0 || actualValue == 0) achievement = 0;
		else achievement = direction == KpiDirection.HigherIsBetter ? actualValue / targetValue * 100 : targetValue / actualValue * 100;
		achievement = cast(double) cast(long) (achievement * 10 + 0.5) / 10;
	}

	void validate() const {
		validateAnnotatedFields(this);
		if (direction == KpiDirection.HigherIsBetter && thresholdValue > targetValue)
			throw new ValidationException("thresholdValue", "With 'higher is better' the threshold must not be above the target");
		if (direction == KpiDirection.LowerIsBetter && thresholdValue < targetValue)
			throw new ValidationException("thresholdValue", "With 'lower is better' the threshold must not be below the target");
		if (measured && measuredAt.length == 0)
			throw new ValidationException("measuredAt", "A measured KPI needs the measurement date");
	}
}

/// Worst status of several KPIs (NoData only if nothing is measured).
KpiStatus worstKpiStatus(const KpiStatus[] all) pure @safe {
	auto worst = KpiStatus.NoData;
	foreach (s; all) if (s > worst) worst = s;
	return worst;
}

unittest {
	with (KpiDirection) {
		assert(ProcessKpi.evaluate(HigherIsBetter, 95, 90, 96, true) == KpiStatus.OnTrack);
		assert(ProcessKpi.evaluate(HigherIsBetter, 95, 90, 92, true) == KpiStatus.AtRisk);
		assert(ProcessKpi.evaluate(HigherIsBetter, 95, 90, 80, true) == KpiStatus.OffTrack);
		assert(ProcessKpi.evaluate(LowerIsBetter, 4, 8, 6, true) == KpiStatus.AtRisk);
		assert(ProcessKpi.evaluate(LowerIsBetter, 4, 8, 6, false) == KpiStatus.NoData);
	}
	assert(worstKpiStatus([KpiStatus.OnTrack, KpiStatus.OffTrack, KpiStatus.NoData]) == KpiStatus.OffTrack);
	auto k = new ProcessKpi;
	k.name = "MTTR"; k.processId = "p"; k.direction = KpiDirection.LowerIsBetter; k.targetValue = 4; k.thresholdValue = 2;
	bool failed;
	try k.validate(); catch (ValidationException e) failed = e.field == "thresholdValue";
	assert(failed);
	k.thresholdValue = 8; k.actualValue = 5; k.measured = true; k.measuredAt = "2026-10-31";
	k.derive();
	k.validate();
	assert(k.kpiStatus == KpiStatus.AtRisk && k.achievement == 80);
}
