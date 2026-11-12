/// Reporting: executes report definitions (set, columns, $filter, $orderby, group by, sum) against the use cases
/// it was created with - with the checked use cases of a caller, only readable sets can be reported on.
module neko.eam.application.usecases.reporting;

import std.algorithm : canFind, map, sort;
import std.array : array, join;
import std.conv : to;
import std.datetime : Clock;
import std.format : format;
import std.math : isNaN;
import vibe.data.json;
import neko.eam.domain.exceptions;
import neko.eam.application.dtos;
import neko.eam.application.services.queryengine;
import neko.eam.ports.usecases;

class ReportingInteractor : IReporting {
	private IEamUseCases _uc;

	this(IEamUseCases uc) { _uc = uc; }

	ReportResultDto run(string reportId, string actor = "system") {
		auto r = runDefinition(_uc.reports.get(reportId), actor);
		r.reportId = reportId;
		return r;
	}

	ReportResultDto[] runBook(string bookId, string actor = "system") {
		return _uc.reportBooks.get(bookId).reportIds.map!(id => run(id, actor)).array;
	}

	ReportResultDto runDefinition(ReportDto d, string actor = "system") {
		validateReportDefinition(d);
		static foreach (S; EamDtoSets)
			if (d.entitySet == S.setName) return execute!S(d, actor);
		throw new ValidationException("entitySet", "Unknown entity set '" ~ d.entitySet ~ "'");
	}

	private ReportResultDto execute(alias S)(ReportDto d, string actor) {
		ReportResultDto r;
		r.reportId = d.id;
		r.name = d.name;
		r.description = d.description;
		r.setName = S.setName;
		r.setLabel = S.label;
		r.filter = d.filter;
		r.orderBy = d.orderBy;
		r.generatedAt = Clock.currTime().toUTC().toISOExtString();
		r.generatedBy = actor;
		auto fields = describeFields!S();
		auto columns = d.columns.length ? d.columns : listColumnNames(fields);
		FieldInfoDto[] cols;
		foreach (c; columns) cols ~= fieldOf(fields, c);
		r.columns = cols.map!(f => ReportColumnDto(f.name, f.label, f.type)).array;

		Json[] items;
		foreach (dto; manage!S(_uc).list) items ~= serializeToJson(dto);
		QueryOptions q;
		q.filter = d.filter;
		q.orderby = d.orderBy.length ? d.orderBy : "name";
		auto matched = applyQuery(items, q).items;
		r.totalCount = matched.length;

		string[string][string] names; // referenced set -> id -> name (only readable sets)
		foreach (f; cols ~ (d.groupBy.length ? [fieldOf(fields, d.groupBy)] : null))
			if (f.reference.length && f.reference !in names) names[f.reference] = nameLookup(f.reference);

		auto limit = d.maxRows > 0 && d.maxRows < matched.length ? d.maxRows : matched.length;
		foreach (row; matched[0 .. limit])
			r.rows ~= cols.map!(f => cell(row[f.name], f, names)).array;

		if (d.groupBy.length) {
			auto g = fieldOf(fields, d.groupBy);
			r.groupBy = g.name;
			r.groupLabel = g.label;
			FieldInfoDto s;
			if (d.sumField.length) { s = fieldOf(fields, d.sumField); r.sumField = s.name; r.sumLabel = s.label; }
			ReportGroupDto[string] groups;
			foreach (row; matched) {
				auto key = cell(row[g.name], g, names);
				if (key.length == 0) key = "–";
				auto cur = groups.get(key, ReportGroupDto(key));
				cur.count++;
				if (s.name.length) {
					auto v = number(row[s.name]);
					cur.sum += v;
					r.totalSum += v;
				}
				groups[key] = cur;
			}
			r.groups = groups.values;
			r.groups.sort!((a, b) => a.count > b.count || (a.count == b.count && a.value < b.value));
		}
		return r;
	}

	/// id -> name of a referenced set; empty if the caller may not read it (ids are shown then).
	private string[string] nameLookup(string setName) {
		string[string] m;
		static foreach (S; EamDtoSets)
			if (S.setName == setName) {
				try foreach (dto; manage!S(_uc).list) m[dto.id] = dto.name;
				catch (AccessDeniedException) {}
			}
		return m;
	}
}

/// Checks columns, group / sum fields and the filter / order syntax of a report definition.
void validateReportDefinition(ReportDto d) {
	static foreach (S; EamDtoSets)
		if (d.entitySet == S.setName) {
			auto fields = describeFields!S();
			foreach (c; d.columns) fieldOf(fields, c, "columns");
			if (d.groupBy.length) fieldOf(fields, d.groupBy, "groupBy");
			if (d.sumField.length) {
				auto f = fieldOf(fields, d.sumField, "sumField");
				if (f.type != "Int32" && f.type != "Double")
					throw new ValidationException("sumField", "'" ~ f.label ~ "' is not numeric");
			}
			// syntax check of $filter / $orderby against an empty element of the set
			QueryOptions q;
			q.filter = d.filter;
			q.orderby = d.orderBy;
			try applyQuery([serializeToJson(S.Dto.init), serializeToJson(S.Dto.init)], q);
			catch (Exception e) throw new ValidationException(d.filter.length ? "filter" : "orderBy", "Invalid query: " ~ e.msg);
			return;
		}
	throw new ValidationException("entitySet", "Unknown entity set '" ~ d.entitySet ~ "'");
}

/// Tables for CSV / XLSX: one per report, plus one per group summary.
TableDto[] reportTables(ReportResultDto[] results) {
	TableDto[] tables;
	foreach (r; results) {
		TableDto t;
		t.name = r.name.length ? r.name : r.setLabel;
		t.columns = r.columns.map!(c => c.label).array;
		t.types = r.columns.map!(c => c.type == "Int32" || c.type == "Double" ? "number" : "string").array;
		t.rows = r.rows;
		tables ~= t;
		if (r.groups.length) {
			TableDto g;
			g.name = t.name ~ " (" ~ r.groupLabel ~ ")";
			g.columns = [r.groupLabel, "Count"] ~ (r.sumField.length ? [r.sumLabel] : null);
			g.types = ["string", "number"] ~ (r.sumField.length ? ["number"] : null);
			foreach (x; r.groups)
				g.rows ~= [x.value, x.count.to!string] ~ (r.sumField.length ? [format("%.15g", x.sum)] : null);
			tables ~= g;
		}
	}
	return tables;
}

private string[] listColumnNames(FieldInfoDto[] fields) {
	string[] r = ["name"];
	foreach (f; fields) if (f.listColumn && f.name != "name") r ~= f.name;
	return r;
}

private FieldInfoDto fieldOf(FieldInfoDto[] fields, string name, string target = "columns") {
	foreach (f; fields) if (f.name == name) return f;
	throw new ValidationException(target, "Unknown field '" ~ name ~ "' (use the technical field names, see 'eam fields <Set>')");
}

private string cell(Json v, FieldInfoDto f, string[string][string] names) {
	string one(Json x) {
		auto s = x.type == Json.Type.string ? x.get!string : x.type == Json.Type.undefined || x.type == Json.Type.null_ ? "" : x.toString;
		if (f.reference.length && s.length) if (auto n = f.reference in names) if (auto name = s in *n) return *name;
		return s;
	}
	if (v.type == Json.Type.array) {
		string[] parts;
		foreach (x; v) parts ~= one(x);
		return parts.join(", ");
	}
	if (v.type == Json.Type.float_) return format("%.15g", v.get!double);
	return one(v);
}

private double number(Json v) {
	if (v.type == Json.Type.int_) return v.get!long;
	if (v.type == Json.Type.float_) return v.get!double;
	return 0;
}

unittest {
	ReportDto d;
	d.entitySet = "Applications";
	d.columns = ["name", "nope"];
	bool failed;
	try validateReportDefinition(d); catch (ValidationException e) failed = e.field == "columns";
	assert(failed);
	d.columns = ["name"]; d.groupBy = "timeCategory"; d.sumField = "release";
	failed = false;
	try validateReportDefinition(d); catch (ValidationException e) failed = e.field == "sumField";
	assert(failed, "sums need a numeric field");
	d.sumField = "annualCost"; d.filter = "annualCost gt";
	failed = false;
	try validateReportDefinition(d); catch (ValidationException e) failed = e.field == "filter";
	assert(failed, "filter syntax is checked");
	d.filter = "annualCost gt 100000 and status eq 'Active'";
	validateReportDefinition(d);
}
