/// Hierarchy paths ("ACME Group / Group IT / Operations") of self-referencing element trees.
module neko.eam.domain.services.hierarchy;

import std.array : join;

/// Path from the root to `element`, following the parent reference field `parentField`.
/// Unknown parents end the path; the visited set guards against cycles in the data.
string hierarchyPath(string parentField, T)(T element, T[] all, string separator = " / ") {
	T[string] byId;
	foreach (e; all) byId[e.id] = e;
	string[] names = [element.name];
	bool[string] seen = [element.id: true];
	string parent = __traits(getMember, element, parentField);
	while (parent.length && parent !in seen) {
		auto p = parent in byId;
		if (p is null) break;
		seen[parent] = true;
		names = (*p).name ~ names;
		parent = __traits(getMember, *p, parentField);
	}
	return names.join(separator);
}

unittest {
	static class N { string id, name, parentId; this(string i, string n, string p) { id = i; name = n; parentId = p; } }
	auto a = new N("a", "A", ""), b = new N("b", "B", "a"), c = new N("c", "C", "b");
	assert(hierarchyPath!"parentId"(c, [a, b, c]) == "A / B / C");
	a.parentId = "c"; // cycle
	assert(hierarchyPath!"parentId"(c, [a, b, c]) == "A / B / C");
	assert(hierarchyPath!"parentId"(new N("x", "X", "missing"), [a]) == "X");
}
