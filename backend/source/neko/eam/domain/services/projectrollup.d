/// Project management: roll-up of work packages into projects and sub projects.
module neko.eam.domain.services.projectrollup;

import std.math : round;
import neko.eam.domain.entities;
import neko.eam.domain.enumerations;

/// Totals of a project or sub project. Progress is the planned-effort weighted mean of the work package
/// progress (unweighted when no effort is planned); cancelled work packages are ignored.
struct ProjectRollup {
	int subProjects;
	int workPackages;
	double plannedEffortDays = 0;
	int progress;

	static ProjectRollup forProject(string projectId, SubProject[] subs, WorkPackage[] wps) {
		ProjectRollup r;
		foreach (s; subs) if (s.projectId == projectId) r.subProjects++;
		WorkPackage[] mine;
		foreach (w; wps) if (w.projectId == projectId) mine ~= w;
		r.aggregate(mine);
		return r;
	}

	static ProjectRollup forSubProject(string subProjectId, SubProject[] subs, WorkPackage[] wps) {
		bool[string] inTree = [subProjectId: true];
		// breadth-first over nested sub projects; the visited set guards against cycles in the data
		for (bool grown = true; grown;) {
			grown = false;
			foreach (s; subs)
				if (s.parentSubProjectId in inTree && s.id !in inTree) { inTree[s.id] = true; grown = true; }
		}
		ProjectRollup r;
		r.subProjects = cast(int) inTree.length - 1;
		WorkPackage[] mine;
		foreach (w; wps) if (w.subProjectId in inTree) mine ~= w;
		r.aggregate(mine);
		return r;
	}

	private void aggregate(WorkPackage[] wps) {
		double weighted = 0, weights = 0, plain = 0;
		int counted;
		foreach (w; wps) {
			workPackages++;
			if (w.status == WorkPackageStatus.Cancelled) continue;
			plannedEffortDays += w.plannedEffortDays;
			weighted += w.progress * w.plannedEffortDays;
			weights += w.plannedEffortDays;
			plain += w.progress;
			counted++;
		}
		if (weights > 0) progress = cast(int) round(weighted / weights);
		else if (counted) progress = cast(int) round(plain / counted);
	}
}

unittest {
	auto s1 = new SubProject; s1.id = "s1"; s1.projectId = "p";
	auto s2 = new SubProject; s2.id = "s2"; s2.projectId = "p"; s2.parentSubProjectId = "s1";
	WorkPackage wp(string sub, double effort, int progress, WorkPackageStatus st = WorkPackageStatus.InProgress) {
		auto w = new WorkPackage; w.projectId = "p"; w.subProjectId = sub; w.plannedEffortDays = effort;
		w.progress = progress; w.status = st; return w;
	}
	auto wps = [wp("s1", 10, 100), wp("s2", 30, 0), wp("", 0, 50, WorkPackageStatus.Cancelled)];
	auto p = ProjectRollup.forProject("p", [s1, s2], wps);
	assert(p.subProjects == 2 && p.workPackages == 3 && p.plannedEffortDays == 40 && p.progress == 25);
	auto r = ProjectRollup.forSubProject("s1", [s1, s2], wps);
	assert(r.subProjects == 1 && r.workPackages == 2 && r.progress == 25);
	assert(ProjectRollup.forSubProject("s2", [s1, s2], wps).progress == 0);
}
