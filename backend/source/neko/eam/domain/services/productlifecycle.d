/// Product lifecycle monitoring: expired milestones, due reminders and blacklisted products in use.
module neko.eam.domain.services.productlifecycle;

import std.algorithm : canFind, filter, map, sort;
import std.array : array;
import neko.eam.domain.entities;
import neko.eam.domain.enumerations;
import neko.eam.domain.types;

struct ProductLifecycleMonitor {
	/// All alerts of all products at `today` (ISO date), most severe first.
	static ProductAlert[] alerts(Product[] products, Application[] apps, string today) {
		ProductAlert[] result;
		foreach (p; products) {
			auto users = apps.filter!(a => a.isOperational
				&& (a.usedProductIds.canFind(p.id) || a.assignedProductIds.canFind(p.id))).map!(a => a.id).array;
			void add(ProductAlertKind kind, string date, RiskLevel severity, string message) {
				// a milestone only becomes critical when the product is still in productive use
				if (users.length == 0 && severity > RiskLevel.Medium) severity = RiskLevel.Medium;
				result ~= ProductAlert(p.id, p.name, p.productVersion, kind, date, severity, message, users);
			}
			if (p.lifecycleStatus == LifecycleStatus.Retired) continue;
			if (p.isBlacklisted && users.length)
				add(ProductAlertKind.Blacklisted, "", RiskLevel.Critical, "Blacklisted product is used by applications");
			if (isBefore(p.endOfLife, today) || p.endOfLife == today)
				add(ProductAlertKind.EndOfLife, p.endOfLife, RiskLevel.Critical, "End of life reached");
			else if (isBefore(p.endOfSecurity, today) || p.endOfSecurity == today)
				add(ProductAlertKind.EndOfSecurity, p.endOfSecurity, RiskLevel.Critical, "No more security updates");
			else if (isBefore(p.endOfSupport, today) || p.endOfSupport == today)
				add(ProductAlertKind.EndOfSupport, p.endOfSupport, RiskLevel.High, "Vendor support ended");
			else {
				if (p.eolReminderDate.length && !isBefore(today, p.eolReminderDate))
					add(ProductAlertKind.ReminderDue, p.endOfLife, RiskLevel.Medium, "End of life within " ~ toStr(p.eolReminderDays) ~ " days");
				if (p.eosuReminderDate.length && !isBefore(today, p.eosuReminderDate))
					add(ProductAlertKind.ReminderDue, p.endOfSupport, RiskLevel.Medium, "End of support within " ~ toStr(p.eosuReminderDays) ~ " days");
			}
			if (isBefore(p.bsiPermissionEndDate, today))
				add(ProductAlertKind.BsiPermissionExpired, p.bsiPermissionEndDate, RiskLevel.High, "BSI permission expired");
			if (isBefore(p.dueDateNextValidation, today))
				add(ProductAlertKind.ValidationOverdue, p.dueDateNextValidation, RiskLevel.Low, "Validation overdue");
		}
		result.sort!((a, b) => a.severity > b.severity || (a.severity == b.severity && a.productName < b.productName));
		return result;
	}

	private static string toStr(int v) {
		import std.conv : to;
		return v.to!string;
	}
}

/// Product totals of an application group: distinct products of all applications in the group's subtree.
struct ApplicationGroupRollup {
	int used;
	int assigned;

	static ApplicationGroupRollup compute(string groupId, ApplicationGroup[] groups, Application[] apps) {
		bool[string] inTree = [groupId: true];
		// breadth-first over the hierarchy; the visited set guards against cycles in the data
		for (bool grown = true; grown;) {
			grown = false;
			foreach (g; groups)
				if (g.parentGroupId in inTree && g.id !in inTree) { inTree[g.id] = true; grown = true; }
		}
		bool[string] used, assigned;
		foreach (a; apps) {
			if (a.applicationGroupId !in inTree) continue;
			foreach (p; a.usedProductIds) used[p] = true;
			foreach (p; a.assignedProductIds) assigned[p] = true;
		}
		return ApplicationGroupRollup(cast(int) used.length, cast(int) assigned.length);
	}
}

unittest {
	auto g1 = new ApplicationGroup; g1.id = "g1";
	auto g2 = new ApplicationGroup; g2.id = "g2"; g2.parentGroupId = "g1";
	auto a1 = new Application; a1.id = "a1"; a1.applicationGroupId = "g1"; a1.usedProductIds = ["p1"];
	auto a2 = new Application; a2.id = "a2"; a2.applicationGroupId = "g2"; a2.usedProductIds = ["p1", "p2"]; a2.assignedProductIds = ["p3"];
	auto r = ApplicationGroupRollup.compute("g1", [g1, g2], [a1, a2]);
	assert(r.used == 2 && r.assigned == 1);
	assert(ApplicationGroupRollup.compute("g2", [g1, g2], [a1, a2]).used == 2);

	auto p = new Product; p.id = "p1"; p.name = "Java 8"; p.endOfSupport = "2022-03-31";
	auto alerts = ProductLifecycleMonitor.alerts([p], [a1], "2026-01-01");
	assert(alerts.length == 1 && alerts[0].kind == ProductAlertKind.EndOfSupport && alerts[0].applicationIds == ["a1"]);
	p.isBlacklisted = true;
	assert(ProductLifecycleMonitor.alerts([p], [a1], "2026-01-01")[0].kind == ProductAlertKind.Blacklisted);
}
