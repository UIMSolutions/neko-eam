/// Application portfolio analysis: TIME rationalisation, technology risks, capability coverage.
module neko.eam.domain.services.portfolioanalyzer;

import std.algorithm : canFind, filter, map;
import std.array : array;
import neko.eam.domain.entities;
import neko.eam.domain.enumerations;
import neko.eam.domain.types;

struct PortfolioAnalyzer {
	/// Gartner TIME quadrant derived from business value and technical fit (1..5, threshold 3).
	static TimeCategory recommendTime(int businessValue, int technicalFit) @safe pure nothrow {
		immutable highValue = businessValue >= 3;
		immutable goodFit = technicalFit >= 3;
		if (highValue && goodFit) return TimeCategory.Invest;
		if (highValue) return TimeCategory.Migrate;
		if (goodFit) return TimeCategory.Tolerate;
		return TimeCategory.Eliminate;
	}

	static TimeAssessment[] assessTime(Application[] apps) {
		TimeAssessment[] result;
		foreach (app; apps) {
			if (app.status == LifecycleStatus.Retired) continue;
			auto rec = recommendTime(app.businessValue, app.technicalFit);
			result ~= TimeAssessment(app.id, app.name, app.businessValue, app.technicalFit,
				app.timeCategory, rec, rec != app.timeCategory);
		}
		return result;
	}

	/// Operational applications that use outdated IT components.
	static TechnologyRisk[] technologyRisks(Application[] apps, ITComponent[] components, string today) {
		ITComponent[string] byId;
		foreach (c; components) byId[c.id] = c;
		TechnologyRisk[] risks;
		foreach (app; apps) {
			if (!app.isOperational) continue;
			foreach (cid; app.componentIds) {
				auto c = cid in byId;
				if (c is null || !(*c).isOutdated(today)) continue;
				string reason = (*c).endOfSupportDate.length && (*c).endOfSupportDate < today
					? "Vendor support ended" : "Component is being phased out";
				risks ~= TechnologyRisk(app.id, app.name, c.id, c.name, c.endOfSupportDate, reason);
			}
		}
		return risks;
	}

	/// Coverage of each capability by operational applications.
	/// A capability is a gap if neither it nor any of its sub-capabilities is supported;
	/// it is redundant if more than one application supports it directly.
	static CapabilityCoverage[] coverage(BusinessCapability[] capabilities, Application[] apps) {
		string[][string] children;
		foreach (cap; capabilities) if (cap.parentId.length) children[cap.parentId] ~= cap.id;
		string[][string] direct;
		foreach (cap; capabilities)
			direct[cap.id] = apps.filter!(a => a.isOperational && a.capabilityIds.canFind(cap.id)).map!(a => a.id).array;

		bool supportedInSubtree(string id, size_t depth) {
			if (depth > capabilities.length) return false; // defensive against cycles
			if (direct.get(id, null).length) return true;
			foreach (child; children.get(id, null))
				if (supportedInSubtree(child, depth + 1)) return true;
			return false;
		}

		CapabilityCoverage[] result;
		foreach (cap; capabilities) {
			auto supporters = direct[cap.id];
			result ~= CapabilityCoverage(cap.id, cap.name, cap.level, supporters,
				!supportedInSubtree(cap.id, 0), supporters.length > 1);
		}
		return result;
	}
}

unittest {
	assert(PortfolioAnalyzer.recommendTime(5, 5) == TimeCategory.Invest);
	assert(PortfolioAnalyzer.recommendTime(5, 1) == TimeCategory.Migrate);
	assert(PortfolioAnalyzer.recommendTime(1, 5) == TimeCategory.Tolerate);
	assert(PortfolioAnalyzer.recommendTime(1, 1) == TimeCategory.Eliminate);

	auto cap = new BusinessCapability; cap.id = "c1"; cap.name = "Sales";
	auto cap2 = new BusinessCapability; cap2.id = "c2"; cap2.name = "HR";
	auto a1 = new Application; a1.id = "a1"; a1.capabilityIds = ["c1"];
	auto a2 = new Application; a2.id = "a2"; a2.capabilityIds = ["c1"];
	auto parent = new BusinessCapability; parent.id = "p"; parent.name = "Parent";
	cap.parentId = "p";
	auto cov = PortfolioAnalyzer.coverage([cap, cap2, parent], [a1, a2]);
	assert(cov[0].redundant && !cov[0].gap);
	assert(cov[1].gap);
	assert(!cov[2].gap, "parent is covered through its child");
}
