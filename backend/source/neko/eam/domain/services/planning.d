/// IT landscape planning: roll-up of measures into measure groups.
module neko.eam.domain.services.planning;

import neko.eam.domain.entities;
import neko.eam.domain.enumerations;

/// Number of measures and their estimated cost in a measure group incl. its sub groups.
/// Rejected and cancelled measures are not counted.
struct MeasureGroupRollup {
	int measures;
	double estimatedCost = 0;

	static MeasureGroupRollup compute(string groupId, MeasureGroup[] groups, Measure[] all) {
		bool[string] inTree = [groupId: true];
		// breadth-first over the hierarchy; the visited set guards against cycles in the data
		for (bool grown = true; grown;) {
			grown = false;
			foreach (g; groups)
				if (g.parentGroupId in inTree && g.id !in inTree) { inTree[g.id] = true; grown = true; }
		}
		MeasureGroupRollup r;
		foreach (m; all) {
			if (m.measureGroupId !in inTree) continue;
			if (m.status == PlanningStatus.Rejected || m.status == PlanningStatus.Cancelled) continue;
			r.measures++;
			r.estimatedCost += m.estimatedCost;
		}
		return r;
	}
}

unittest {
	auto g1 = new MeasureGroup; g1.id = "g1";
	auto g2 = new MeasureGroup; g2.id = "g2"; g2.parentGroupId = "g1";
	auto m1 = new Measure; m1.measureGroupId = "g1"; m1.estimatedCost = 100;
	auto m2 = new Measure; m2.measureGroupId = "g2"; m2.estimatedCost = 50;
	auto m3 = new Measure; m3.measureGroupId = "g2"; m3.estimatedCost = 999; m3.status = PlanningStatus.Cancelled;
	auto r = MeasureGroupRollup.compute("g1", [g1, g2], [m1, m2, m3]);
	assert(r.measures == 2 && r.estimatedCost == 150);
	assert(MeasureGroupRollup.compute("g2", [g1, g2], [m1, m2, m3]).measures == 1);
}
