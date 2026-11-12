/// Impact analysis: what is affected if an application changes or is switched off.
module neko.eam.domain.services.impactanalyzer;

import std.algorithm : canFind, sort, uniq;
import std.array : array;
import neko.eam.domain.entities;
import neko.eam.domain.types;

struct ImpactAnalyzer {
	static Impact analyze(Application app, InformationFlow[] flows, Project[] projects) {
		Impact impact;
		impact.applicationId = app.id;
		impact.applicationName = app.name;
		impact.capabilityIds = app.capabilityIds.dup;
		impact.componentIds = app.componentIds.dup;
		foreach (f; flows) {
			if (f.sourceApplicationId == app.id) {
				impact.outgoingFlowIds ~= f.id;
				impact.dependentApplicationIds ~= f.targetApplicationId;
			}
			if (f.targetApplicationId == app.id) {
				impact.incomingFlowIds ~= f.id;
				impact.providingApplicationIds ~= f.sourceApplicationId;
			}
		}
		impact.dependentApplicationIds = impact.dependentApplicationIds.sort.uniq.array;
		impact.providingApplicationIds = impact.providingApplicationIds.sort.uniq.array;
		foreach (p; projects)
			if (p.affectedApplicationIds.canFind(app.id))
				impact.projectIds ~= p.id;
		return impact;
	}
}

unittest {
	auto a = new Application; a.id = "a";
	auto f = new InformationFlow; f.id = "f"; f.sourceApplicationId = "a"; f.targetApplicationId = "b";
	auto i = ImpactAnalyzer.analyze(a, [f], []);
	assert(i.dependentApplicationIds == ["b"] && i.outgoingFlowIds == ["f"]);
}
