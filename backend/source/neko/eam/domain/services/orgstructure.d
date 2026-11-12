/// Organisation structure: staffing figures of organisational units and enterprises from their members.
module neko.eam.domain.services.orgstructure;

import std.algorithm : canFind;
import neko.eam.domain.entities;
import neko.eam.domain.enumerations;

/// Current staffing of one organisational unit (direct members only).
struct UnitStaffing {
	string head;                      /// name of the current head ("" if vacant)
	int members;
	double capacityFte = 0;

	static UnitStaffing compute(string unitId, Member[] members, string today) {
		UnitStaffing s;
		foreach (m; members) {
			if (m.organizationId != unitId || !m.isCurrent(today)) continue;
			s.members++;
			s.capacityFte += m.capacity / 100.0;
			if (m.memberFunction == MemberFunction.Head) s.head = m.name;
		}
		return s;
	}

	/// Units and current members of an enterprise; the managing director is the current head of its
	/// top-level unit(s) - units without a parent unit of the same enterprise.
	static void forEnterprise(string enterpriseId, Organization[] units, Member[] members, string today,
			out int unitCount, out int memberCount, out string managingDirector) {
		import std.array : join;
		string[] ids, roots, heads;
		foreach (u; units) if (u.enterpriseId == enterpriseId) ids ~= u.id;
		foreach (u; units)
			if (u.enterpriseId == enterpriseId && !ids.canFind(u.parentId)) roots ~= u.id;
		unitCount = cast(int) ids.length;
		foreach (m; members) {
			if (!m.isCurrent(today)) continue;
			if (ids.canFind(m.organizationId)) memberCount++;
			if (roots.canFind(m.organizationId) && m.memberFunction == MemberFunction.Head) heads ~= m.name;
		}
		managingDirector = heads.join(", ");
	}
}

unittest {
	auto head = new Member; head.name = "M. Weber"; head.organizationId = "u"; head.memberFunction = MemberFunction.Head;
	auto part = new Member; part.name = "A"; part.organizationId = "u"; part.capacity = 50;
	auto left = new Member; left.name = "B"; left.organizationId = "u"; left.endDate = "2025-12-31";
	auto s = UnitStaffing.compute("u", [head, part, left], "2026-11-12");
	assert(s.head == "M. Weber" && s.members == 2 && s.capacityFte == 1.5);
	auto unit = new Organization; unit.id = "u"; unit.enterpriseId = "e";
	int units, people;
	string md;
	UnitStaffing.forEnterprise("e", [unit], [head, part, left], "2026-11-12", units, people, md);
	assert(units == 1 && people == 2 && md == "M. Weber");
}
