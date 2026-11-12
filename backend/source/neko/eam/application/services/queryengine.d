/// OData v4 system query options: $filter, $orderby, $select, $top, $skip, $count, $search.
/// $filter supports eq ne gt ge lt le, and/or/not, parentheses, contains/startswith/endswith,
/// tolower/toupper/length and lambda `any` on collections, e.g. `capabilityIds/any(c:c eq 'cap-crm')`.
module neko.eam.application.services.queryengine;

import std.algorithm : sort, map, filter, canFind, startsWith, endsWith, among;
import std.array : array, split;
import std.ascii : isDigit, isAlphaNum, isWhite;
import std.conv : to;
import std.string : strip, toLower, toUpper, indexOf;
import vibe.data.json;

class ODataQueryException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) @safe pure nothrow { super(msg, file, line); }
}

struct QueryOptions {
	string filter, orderby, select, search;
	long top = -1, skip = 0;
	bool count;

	static QueryOptions parse(string[string] params) {
		QueryOptions q;
		foreach (k, v; params) {
			switch (k) {
				case "$filter": q.filter = v; break;
				case "$orderby": q.orderby = v; break;
				case "$select": q.select = v; break;
				case "$search": q.search = v; break;
				case "$top": q.top = parseNonNegative(k, v); break;
				case "$skip": q.skip = parseNonNegative(k, v); break;
				case "$count": q.count = v == "true"; break;
				default: break; // $format, sap-* and custom options are ignored
			}
		}
		return q;
	}
}

private long parseNonNegative(string k, string v) {
	try {
		auto n = v.to!long;
		if (n >= 0) return n;
	} catch (Exception) {}
	throw new ODataQueryException(k ~ " must be a non-negative integer");
}

/// Result of applying the options to a collection.
struct QueryResult {
	Json[] items;
	size_t totalCount; /// count after $filter/$search, before paging
}

QueryResult applyQuery(Json[] items, QueryOptions q) {
	Json[] rows = items;
	if (q.search.length) {
		auto needle = q.search.strip(`"`).toLower;
		rows = rows.filter!(r => matchesSearch(r, needle)).array;
	}
	if (q.filter.length) {
		auto expr = FilterParser(q.filter).parseAll();
		rows = rows.filter!(r => truthy(expr.eval(r, null))).array;
	}
	if (q.orderby.length) rows = orderBy(rows, q.orderby);
	QueryResult res;
	res.totalCount = rows.length;
	auto skip = q.skip > rows.length ? rows.length : cast(size_t) q.skip;
	rows = rows[skip .. $];
	if (q.top >= 0 && q.top < rows.length) rows = rows[0 .. cast(size_t) q.top];
	if (q.select.length) rows = rows.map!(r => selectFields(r, q.select)).array;
	res.items = rows;
	return res;
}

private bool matchesSearch(Json row, string needle) {
	foreach (string k, v; row)
		if (v.type == Json.Type.string && v.get!string.toLower.canFind(needle)) return true;
	return false;
}

Json selectFields(Json row, string select) {
	auto r = Json.emptyObject;
	r["id"] = row["id"];
	foreach (f; select.split(",")) {
		auto name = f.strip;
		if (name == "*") return row;
		if (name.length) {
			if (row[name].type == Json.Type.undefined) throw new ODataQueryException("Unknown property '" ~ name ~ "' in $select");
			r[name] = row[name];
		}
	}
	return r;
}

private Json[] orderBy(Json[] rows, string spec) {
	struct Key { string name; bool desc; }
	Key[] keys;
	foreach (part; spec.split(",")) {
		auto p = part.strip.split(" ");
		if (!p.length || !p[0].length) continue;
		keys ~= Key(p[0], p.length > 1 && p[$ - 1].toLower == "desc");
	}
	auto copy = rows.dup;
	copy.sort!((a, b) {
		foreach (k; keys) {
			auto c = compareJson(a[k.name], b[k.name]);
			if (c != 0) return k.desc ? c > 0 : c < 0;
		}
		return false;
	});
	return copy;
}

/// Total order on JSON scalars (undefined/null first).
int compareJson(Json a, Json b) {
	bool an = a.type == Json.Type.null_ || a.type == Json.Type.undefined;
	bool bn = b.type == Json.Type.null_ || b.type == Json.Type.undefined;
	if (an || bn) return an == bn ? 0 : (an ? -1 : 1);
	if (isNumber(a) && isNumber(b)) {
		auto x = a.to!double, y = b.to!double;
		return x < y ? -1 : x > y ? 1 : 0;
	}
	if (a.type == Json.Type.bool_ && b.type == Json.Type.bool_)
		return a.get!bool == b.get!bool ? 0 : (a.get!bool ? 1 : -1);
	auto x = a.to!string, y = b.to!string;
	return x < y ? -1 : x > y ? 1 : 0;
}

private bool isNumber(Json j) { return j.type == Json.Type.int_ || j.type == Json.Type.float_ || j.type == Json.Type.bigInt; }
private bool truthy(Json j) { return j.type == Json.Type.bool_ && j.get!bool; }

// ---------------------------------------------------------------- $filter AST

private abstract class Node {
	abstract Json eval(Json row, Json[string] vars);
}

private final class Literal : Node {
	Json value;
	this(Json v) { value = v; }
	override Json eval(Json, Json[string]) { return value; }
}

private final class Property : Node {
	string[] path;
	this(string[] p) { path = p; }
	override Json eval(Json row, Json[string] vars) {
		Json cur;
		size_t start = 0;
		if (auto v = path[0] in vars) { cur = *v; start = 1; }
		else cur = row;
		foreach (seg; path[start .. $]) {
			if (cur.type != Json.Type.object) return Json(null);
			cur = cur[seg];
			if (cur.type == Json.Type.undefined)
				throw new ODataQueryException("Unknown property '" ~ seg ~ "' in $filter");
		}
		return cur;
	}
}

private final class Binary : Node {
	string op; Node l, r;
	this(string o, Node a, Node b) { op = o; l = a; r = b; }
	override Json eval(Json row, Json[string] vars) {
		if (op == "and") return Json(truthy(l.eval(row, vars)) && truthy(r.eval(row, vars)));
		if (op == "or") return Json(truthy(l.eval(row, vars)) || truthy(r.eval(row, vars)));
		auto a = l.eval(row, vars), b = r.eval(row, vars);
		auto c = compareJson(a, b);
		switch (op) {
			case "eq": return Json(c == 0);
			case "ne": return Json(c != 0);
			case "gt": return Json(c > 0);
			case "ge": return Json(c >= 0);
			case "lt": return Json(c < 0);
			case "le": return Json(c <= 0);
			default: throw new ODataQueryException("Unsupported operator " ~ op);
		}
	}
}

private final class Not : Node {
	Node inner;
	this(Node n) { inner = n; }
	override Json eval(Json row, Json[string] vars) { return Json(!truthy(inner.eval(row, vars))); }
}

private final class Call : Node {
	string fn; Node[] args;
	this(string f, Node[] a) { fn = f; args = a; }
	override Json eval(Json row, Json[string] vars) {
		Json[] v = args.map!(a => a.eval(row, vars)).array;
		string s(size_t i) { return v[i].type == Json.Type.string ? v[i].get!string : ""; }
		switch (fn) {
			case "contains": need(2, v); return Json(s(0).toLower.canFind(s(1).toLower));
			case "startswith": need(2, v); return Json(s(0).startsWith(s(1)));
			case "endswith": need(2, v); return Json(s(0).endsWith(s(1)));
			case "tolower": need(1, v); return Json(s(0).toLower);
			case "toupper": need(1, v); return Json(s(0).toUpper);
			case "length": need(1, v); return Json(cast(long) s(0).length);
			default: throw new ODataQueryException("Unsupported function " ~ fn);
		}
	}
	private void need(size_t n, Json[] v) {
		if (v.length != n) throw new ODataQueryException(fn ~ " expects " ~ n.to!string ~ " arguments");
	}
}

private final class AnyLambda : Node {
	Property collection; string var; Node body;
	this(Property c, string v, Node b) { collection = c; var = v; body = b; }
	override Json eval(Json row, Json[string] vars) {
		auto coll = collection.eval(row, vars);
		if (coll.type != Json.Type.array) return Json(false);
		foreach (e; coll) {
			auto scoped = vars.dup;
			scoped[var] = e;
			if (truthy(body.eval(row, scoped))) return Json(true);
		}
		return Json(false);
	}
}

// ---------------------------------------------------------------- parser

private struct Token { enum Kind { word, str, punct, end } Kind kind; string text; }

private struct FilterParser {
	Token[] toks;
	size_t pos;

	this(string input) { toks = tokenize(input); }

	Node parseAll() {
		auto n = parseOr();
		if (peek.kind != Token.Kind.end) throw new ODataQueryException("Unexpected '" ~ peek.text ~ "' in $filter");
		return n;
	}

	private Token peek() { return toks[pos]; }
	private Token next() { return toks[pos++]; }
	private bool isWord(string w) { return peek.kind == Token.Kind.word && peek.text == w; }
	private void expect(string p) {
		if (peek.kind != Token.Kind.punct || peek.text != p) throw new ODataQueryException("Expected '" ~ p ~ "' in $filter");
		pos++;
	}

	Node parseOr() {
		auto l = parseAnd();
		while (isWord("or")) { pos++; l = new Binary("or", l, parseAnd()); }
		return l;
	}

	Node parseAnd() {
		auto l = parseNot();
		while (isWord("and")) { pos++; l = new Binary("and", l, parseNot()); }
		return l;
	}

	Node parseNot() {
		if (isWord("not")) { pos++; return new Not(parseNot()); }
		return parseCompare();
	}

	Node parseCompare() {
		auto l = parsePrimary();
		if (peek.kind == Token.Kind.word && peek.text.among("eq", "ne", "gt", "ge", "lt", "le")) {
			auto op = next().text;
			return new Binary(op, l, parsePrimary());
		}
		return l;
	}

	Node parsePrimary() {
		auto t = next();
		final switch (t.kind) {
			case Token.Kind.end: throw new ODataQueryException("Unexpected end of $filter");
			case Token.Kind.str: return new Literal(Json(t.text));
			case Token.Kind.punct:
				if (t.text == "(") { auto n = parseOr(); expect(")"); return n; }
				throw new ODataQueryException("Unexpected '" ~ t.text ~ "' in $filter");
			case Token.Kind.word:
				if (t.text == "true") return new Literal(Json(true));
				if (t.text == "false") return new Literal(Json(false));
				if (t.text == "null") return new Literal(Json(null));
				if (t.text[0].isDigit || t.text[0] == '-') {
					if (t.text.indexOf('-', 1) > 0) return new Literal(Json(t.text)); // date literal 2026-01-01
					try {
						return t.text.canFind('.') ? new Literal(Json(t.text.to!double)) : new Literal(Json(t.text.to!long));
					} catch (Exception) throw new ODataQueryException("Invalid number '" ~ t.text ~ "'");
				}
				if (peek.kind == Token.Kind.punct && peek.text == "(") {
					pos++;
					Node[] args;
					if (!(peek.kind == Token.Kind.punct && peek.text == ")")) {
						args ~= parseOr();
						while (peek.kind == Token.Kind.punct && peek.text == ",") { pos++; args ~= parseOr(); }
					}
					expect(")");
					return new Call(t.text, args);
				}
				string[] path = [t.text];
				while (peek.kind == Token.Kind.punct && peek.text == "/") {
					pos++;
					auto seg = next();
					if (seg.kind != Token.Kind.word) throw new ODataQueryException("Invalid property path");
					if (seg.text == "any") {
						expect("(");
						auto v = next().text;
						expect(":");
						auto body = parseOr();
						expect(")");
						return new AnyLambda(new Property(path), v, body);
					}
					path ~= seg.text;
				}
				return new Property(path);
		}
	}

	static Token[] tokenize(string s) {
		Token[] r;
		size_t i;
		while (i < s.length) {
			auto c = s[i];
			if (c.isWhite) { i++; continue; }
			if (c == '\'') {
				string v;
				i++;
				while (true) {
					if (i >= s.length) throw new ODataQueryException("Unterminated string literal in $filter");
					if (s[i] == '\'') {
						if (i + 1 < s.length && s[i + 1] == '\'') { v ~= '\''; i += 2; continue; }
						i++;
						break;
					}
					v ~= s[i++];
				}
				r ~= Token(Token.Kind.str, v);
			} else if ("()/,:".canFind(c)) {
				r ~= Token(Token.Kind.punct, [c].idup);
				i++;
			} else {
				auto start = i;
				while (i < s.length && (s[i].isAlphaNum || s[i] == '_' || s[i] == '.' || s[i] == '-' || s[i] == '$')) i++;
				if (start == i) throw new ODataQueryException("Unexpected character '" ~ c ~ "' in $filter");
				r ~= Token(Token.Kind.word, s[start .. i]);
			}
		}
		r ~= Token(Token.Kind.end, "");
		return r;
	}
}

unittest {
	auto rows = [
		parseJsonString(`{"id":"1","name":"CRM","businessValue":5,"status":"Active","capabilityIds":["c1"]}`),
		parseJsonString(`{"id":"2","name":"Legacy DB","businessValue":2,"status":"PhaseOut","capabilityIds":["c1","c2"]}`),
		parseJsonString(`{"id":"3","name":"BI","businessValue":4,"status":"Active","capabilityIds":[]}`),
	];
	QueryOptions q;
	q.filter = "status eq 'Active' and businessValue ge 4";
	assert(applyQuery(rows, q).items.length == 2);
	q.filter = "contains(name,'legacy') or capabilityIds/any(c:c eq 'c2')";
	assert(applyQuery(rows, q).items.length == 1);
	q.filter = "not (status eq 'Active')";
	assert(applyQuery(rows, q).items[0]["id"].get!string == "2");
	q = QueryOptions.init;
	q.orderby = "businessValue desc";
	q.top = 2; q.count = true; q.select = "name";
	auto res = applyQuery(rows, q);
	assert(res.totalCount == 3 && res.items.length == 2 && res.items[0]["name"].get!string == "CRM");
	assert(res.items[0]["businessValue"].type == Json.Type.undefined);
	bool failed;
	q = QueryOptions.init; q.filter = "name eq";
	try applyQuery(rows, q); catch (ODataQueryException) failed = true;
	assert(failed);
}
