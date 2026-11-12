/// Import and export of entity sets as tables (the file formats live behind ITableCodec).
///
/// Export: one column per DTO field (labels or field names as headers), one row per element.
/// Import: upsert by ID through the regular use cases, so every validation and integrity rule applies.
/// Rows that reference elements further down in the file are retried until no more progress is made.
module neko.eam.application.usecases.transferelements;

import std.algorithm : canFind, count, countUntil, map, splitter, all;
import std.array : array, join;
import std.conv : to, ConvException;
import std.format : format;
import std.string : strip, toLower, indexOf;
import std.traits : FieldNameTuple, isSomeString;
import neko.eam.domain.exceptions;
import neko.eam.application.dtos;
import neko.eam.ports.usecases;
import neko.eam.domain.exceptions : AccessDeniedException;

/// Sheet order of exports and processing order of imports: referenced kinds first.
immutable string[] transferOrder = ["Enterprises", "Organizations", "BusinessCapabilities", "ITComponents", "ProductGroups",
	"Products", "ApplicationGroups", "Applications", "InformationFlows", "Projects", "BusinessProcesses",
	"BusinessData", "ServiceProductGroups", "StrategicGuidelines", "ServiceCapabilities", "MeasureGroups", "Measures",
	"ArchitecturePrinciples", "ArchitectureGuidelines", "ReferenceArchitectures", "ArchitectureDocuments",
	"SubProjects", "WorkPackages",
	"Permissions", "Roles", "Users", "Members", "ITProcesses", "ProcessSteps", "ProcessKpis", "SecurityControls",
	"SecurityRisks", "ProtectionRequirements", "Reports", "ReportBooks"];

class TransferElementsInteractor : ITransferElements {
	private {
		IEamUseCases _uc;
		IEamUseCases delegate() _sandbox;
	}

	/// `sandbox` creates use cases on a throw-away copy of the repository (used for dry runs).
	this(IEamUseCases uc, IEamUseCases delegate() sandbox) {
		_uc = uc;
		_sandbox = sandbox;
	}

	TableDto exportSet(string setName, bool technicalHeaders = false) {
		static foreach (S; EamDtoSets)
			if (S.setName == setName) return exportOf!S(_uc, technicalHeaders);
		throw unknownSet(setName);
	}

	TableDto[] exportAll(bool technicalHeaders = false) {
		TableDto[] sheets;
		foreach (name; transferOrder) {
			try sheets ~= exportSet(name, technicalHeaders);
			catch (AccessDeniedException) {} // sets the caller may not read are left out
		}
		return sheets;
	}

	ImportResultDto importSet(string setName, TableDto table, string actor, bool dryRun = false) {
		if (resolveSet(setName).length == 0) throw unknownSet(setName);
		table.name = resolveSet(setName);
		return importAll([table], actor, dryRun)[0];
	}

	ImportResultDto[] importAll(TableDto[] sheets, string actor, bool dryRun = false) {
		auto target = dryRun ? _sandbox() : _uc;
		ImportResultDto[] results;
		RowJob[] jobs;
		size_t[string] resultIndex;
		// known sheets in dependency order, then the ignored ones
		foreach (name; transferOrder)
			foreach (ref sheet; sheets)
				if (resolveSet(sheet.name) == name && name !in resultIndex) {
					resultIndex[name] = results.length;
					results ~= ImportResultDto(name);
					results[$ - 1].dryRun = dryRun;
					static foreach (S; EamDtoSets)
						if (S.setName == name) jobs ~= planImport!S(target, sheet, actor, results[$ - 1]);
				}
		foreach (ref sheet; sheets)
			if (resolveSet(sheet.name).length == 0) {
				auto r = ImportResultDto(sheet.name);
				r.dryRun = dryRun;
				r.issues ~= ImportIssueDto(0, "", "", "Sheet '" ~ sheet.name ~ "' is not an entity set and was ignored", "Warning");
				results ~= r;
			}
		runJobs(jobs, results, resultIndex);
		return results;
	}

	/// Executes the row jobs. A row failing with a referential integrity error is retried in the next round
	/// (it may reference an element that a later row creates); the loop stops when a round makes no progress.
	private static void runJobs(RowJob[] jobs, ImportResultDto[] results, size_t[string] index) {
		auto pending = jobs;
		while (pending.length) {
			RowJob[] retry;
			foreach (job; pending) {
				auto r = &results[index[job.setName]];
				try {
					final switch (job.run()) {
						case Outcome.created: r.created++; break;
						case Outcome.updated: r.updated++; break;
						case Outcome.unchanged: r.unchanged++; break;
					}
				} catch (ReferentialIntegrityException e) {
					job.lastError = e.msg;
					retry ~= job;
				} catch (ValidationException e) {
					r.failed++;
					r.issues ~= ImportIssueDto(job.row, job.id, e.field, e.msg, "Error");
				} catch (DomainException e) {
					r.failed++;
					r.issues ~= ImportIssueDto(job.row, job.id, "", e.msg, "Error");
				}
			}
			if (retry.length == pending.length) {
				foreach (job; retry) {
					auto r = &results[index[job.setName]];
					r.failed++;
					r.issues ~= ImportIssueDto(job.row, job.id, "", job.lastError, "Error");
				}
				break;
			}
			pending = retry;
		}
		foreach (ref r; results) {
			import std.algorithm : sort;
			r.issues.sort!((a, b) => a.row < b.row);
		}
	}

	private static Exception unknownSet(string name) {
		return new ValidationException("set", "Unknown entity set '" ~ name ~ "'");
	}
}

private enum Outcome { created, updated, unchanged }

private struct RowJob {
	string setName;
	size_t row;
	string id;
	Outcome delegate() run;
	string lastError;
}

/// Entity set for a sheet / set name: set name or label, case insensitive ("" if none).
string resolveSet(string name) {
	auto n = name.strip.toLower;
	static foreach (S; EamDtoSets)
		if (n == S.setName.toLower || n == S.label.toLower || n == S.typeName.toLower) return S.setName;
	return "";
}

private TableDto exportOf(alias S)(IEamUseCases uc, bool technicalHeaders) {
	auto fields = describeFields!S();
	TableDto t;
	t.name = S.setName;
	foreach (f; fields) {
		t.columns ~= technicalHeaders ? f.name : f.label;
		t.types ~= f.type;
	}
	foreach (dto; manage!S(uc).list) {
		auto v = cellValues(dto);
		t.rows ~= fields.map!(f => v.get(f.name, "")).array;
	}
	return t;
}

/// Cell text of every DTO field: collections joined with ", ", doubles without exponent.
string[string] cellValues(T)(const T dto) {
	string[string] r;
	static foreach (name; FieldNameTuple!T) {{
		auto v = __traits(getMember, dto, name);
		static if (is(typeof(v) : const(string[]))) r[name] = v.join(", ");
		else static if (isSomeString!(typeof(v))) r[name] = v;
		else static if (is(typeof(v) : const double) && !is(typeof(v) : const long)) r[name] = format("%.15g", v);
		else r[name] = v.to!string;
	}}
	return r;
}

/// Maps the header row to fields and creates one job per non-empty row.
private RowJob[] planImport(alias S)(IEamUseCases uc, ref TableDto table, string actor, ref ImportResultDto result) {
	auto fields = describeFields!S();
	// column index -> field (index into `fields`), -1 for ignored columns
	auto columnField = new long[table.columns.length];
	bool[string] seen;
	foreach (c, header; table.columns) {
		columnField[c] = -1;
		auto h = header.strip.toLower;
		if (h.length == 0) continue;
		auto fi = fields.countUntil!(f => f.name.toLower == h || f.label.toLower == h);
		if (fi < 0) {
			result.issues ~= ImportIssueDto(1, "", "", "Unknown column '" ~ header ~ "' ignored", "Warning");
			continue;
		}
		if (fields[fi].name in seen) {
			result.issues ~= ImportIssueDto(1, "", fields[fi].name, "Duplicate column '" ~ header ~ "' ignored", "Warning");
			continue;
		}
		seen[fields[fi].name] = true;
		// derived values are recomputed by the domain; administrative fields are set by the use cases
		if (fields[fi].readOnly) continue;
		columnField[c] = fi;
	}
	if ("name" !in seen)
		result.issues ~= ImportIssueDto(1, "", "name", "No 'Name' column: only existing elements can be updated", "Warning");

	RowJob[] jobs;
	foreach (i, cells; table.rows) {
		if (cells.all!(c => c.strip.length == 0)) continue;
		result.rows++;
		immutable rowNo = i + 2;
		string id;
		string[string] values;
		string error, errorField;
		foreach (c, fi; columnField) {
			if (fi < 0) continue;
			auto raw = c < cells.length ? cells[c] : "";
			auto f = fields[fi];
			if (f.name == "id") { id = raw.strip; continue; }
			try values[f.name] = normalizeCell(f, raw);
			catch (ValidationException e) { error = e.msg; errorField = f.name; break; }
		}
		if (error.length) {
			result.failed++;
			result.issues ~= ImportIssueDto(rowNo, id, errorField, error, "Error");
			continue;
		}
		jobs ~= RowJob(S.setName, rowNo, id, rowAction!S(uc, id, values, actor));
	}
	return jobs;
}

/// Create or update of one row (own function so that every delegate gets its own closure).
private Outcome delegate() rowAction(alias S)(IEamUseCases uc, string id, string[string] values, string actor) {
	return () {
		auto m = manage!S(uc);
		S.Dto existing;
		bool found;
		if (id.length) {
			try { existing = m.get(id); found = true; }
			catch (EntityNotFoundException) {}
		}
		if (found) {
			auto dto = existing;
			dto.applyStringValues(values);
			if (cellValues(dto) == cellValues(existing)) return Outcome.unchanged;
			m.update(id, dto, actor);
			return Outcome.updated;
		}
		S.Dto dto;
		dto.applyStringValues(values);
		dto.id = id;
		m.create(dto, actor);
		return Outcome.created;
	};
}

/// Converts a cell into the canonical string form expected by `applyStringValues`.
/// Accepts spreadsheet conventions: yes/no/x for booleans, decimal commas, Excel date serials,
/// dd.mm.yyyy dates, enumeration values in any case, collections separated by `,` or `;`.
string normalizeCell(FieldInfoDto f, string raw) {
	auto v = raw.strip;
	switch (f.type) {
		case "Boolean":
			switch (v.toLower) {
				case "true", "yes", "y", "ja", "j", "1", "x", "wahr": return "true";
				case "false", "no", "n", "nein", "0", "", "falsch": return "false";
				default: throw new ValidationException(f.name, format("'%s': '%s' is not a yes/no value", f.label, raw));
			}
		case "Int32", "Double":
			if (v.length == 0) return f.defaultValue;
			if (v.indexOf(',') >= 0 && v.indexOf('.') < 0) v = v.replaceChar(',', '.');
			try {
				auto d = v.to!double;
				if (f.type == "Double") return format("%.15g", d);
				if (d != cast(long) d) throw new ConvException("fraction");
				return (cast(long) d).to!string;
			} catch (ConvException) {
				throw new ValidationException(f.name, format("'%s': '%s' is not a number", f.label, raw));
			}
		case "Date":
			return normalizeDate(f, v);
		case "StringCollection":
			return v.splitter!(c => c == ',' || c == ';' || c == '\n').map!(s => s.strip).array.join(",");
		default:
			if (f.choices.length) {
				if (v.length == 0) return f.defaultValue;
				auto lower = v.toLower;
				foreach (choice; f.choices)
					if (choice.toLower == lower || humanize(choice).toLower == lower) return choice;
				throw new ValidationException(f.name, format("'%s': '%s' is not one of %s", f.label, raw, f.choices.join(", ")));
			}
			return raw;
	}
}

private string normalizeDate(FieldInfoDto f, string v) {
	import std.datetime.date : Date;
	if (v.length == 0) return "";
	try {
		// Excel date serial (days since 1899-12-30), as delivered by numeric XLSX cells
		if (v.all!(c => (c >= '0' && c <= '9') || c == '.') && v.count('.') <= 1) {
			auto serial = cast(long) v.to!double;
			if (serial > 0 && serial < 2_958_466) {
				import core.time : days;
				return (Date(1899, 12, 30) + days(serial)).toISOExtString();
			}
		}
		if (v.length >= 10 && v[4] == '-' && v[7] == '-') return v[0 .. 10]; // ISO, possibly with a time part
		auto parts = v.split('.');
		if (parts.length == 3) // German dd.mm.yyyy
			return Date(parts[2].strip.to!int, parts[1].to!int, parts[0].to!int).toISOExtString();
		if (v.indexOf('/') > 0) { // mm/dd/yyyy as written by US spreadsheets
			auto p = v.split('/');
			if (p.length == 3) return Date(p[2].strip.to!int, p[0].to!int, p[1].to!int).toISOExtString();
		}
	} catch (Exception) {}
	throw new ValidationException(f.name, format("'%s': '%s' is not a date (YYYY-MM-DD)", f.label, v));
}

private string replaceChar(string s, char from, char to) {
	auto r = s.dup;
	foreach (ref c; r) if (c == from) c = to;
	return r.idup;
}

private string[] split(string s, char sep) {
	import std.array : asplit = split;
	return s.asplit(sep);
}

unittest {
	FieldInfoDto b = { name: "isBlacklisted", label: "IsBlacklisted", type: "Boolean" };
	assert(normalizeCell(b, " Ja ") == "true" && normalizeCell(b, "") == "false");
	FieldInfoDto d = { name: "endOfLife", label: "End of Life", type: "Date" };
	assert(normalizeCell(d, "45658") == "2025-01-01");
	assert(normalizeCell(d, "31.12.2030") == "2030-12-31");
	assert(normalizeCell(d, "2027-02-28T00:00:00") == "2027-02-28");
	FieldInfoDto n = { name: "licenseCosts", label: "License costs", type: "Double", defaultValue: "0" };
	assert(normalizeCell(n, "1234,5") == "1234.5" && normalizeCell(n, "") == "0");
	FieldInfoDto i = { name: "level", label: "Level", type: "Int32", defaultValue: "1" };
	assert(normalizeCell(i, "3.0") == "3");
	FieldInfoDto e = { name: "status", label: "Status", type: "String", choices: ["Plan", "PhaseOut"] };
	assert(normalizeCell(e, "phase out") == "PhaseOut");
	bool failed;
	try normalizeCell(e, "Bogus"); catch (ValidationException ex) failed = ex.field == "status";
	assert(failed);
	FieldInfoDto c = { name: "capabilityIds", label: "Caps", type: "StringCollection" };
	assert(normalizeCell(c, "a; b ,c") == "a,b,c");
	assert(resolveSet("business capabilities") == "BusinessCapabilities" && resolveSet("Sheet1") == "");
}
