/// Command-line interface & administrative commands (local repository or remote server via OData).
module neko.eam.presentation.cli;

import neko.eam.domain.exceptions : AccessDeniedException;
import std.algorithm : map, max, startsWith, canFind, filter, any;
import std.array : array, join, split;
import std.conv : to;
import std.format : format;
import std.file : write;
static import std.file;
import std.range : repeat;
import std.stdio : writeln, writefln, stderr;
import std.string : indexOf, leftJustify, replace;
import vibe.data.json;
import neko.eam.ports.usecases;
import neko.eam.infrastructure.clients : ODataClient;
import neko.eam.infrastructure.formats : codecFor, codecForContent;
import neko.eam.presentation.http.transfer : pickSheet;
import neko.eam.infrastructure.security : localUserName;
import neko.eam.presentation.http.jsoncodec;
import neko.eam.presentation.http.errors : classify;
import neko.eam.presentation.odata.query;

enum cliUsage = `Neko EAM - Enterprise Architecture Management

Usage: eam <command> [arguments] [options]

Modes:
  serve                          start HTTP server (OData v4, REST, web cockpit, Fiori app)
  gui                            start the native GtkD desktop client
  webview [--url URL]            open the Fiori app in a desktop WebView (embedded server unless --url)

Repository commands:
  sets                           list element sets and their fields
  fields <Set>                   describe the fields of a set (label, type, group, values)
  list <Set> [--filter F] [--orderby O] [--top N] [--fields a,b]
                                 list elements (F/O use OData syntax, e.g. "status eq 'Active'")
  show <Set> <id>                show one element
  create <Set> field=value ...   create an element (arrays comma separated)
  update <Set> <id> field=value  update fields of an element
  delete <Set> <id>              delete an element (fails while referenced)

Analysis:
  analyze portfolio              portfolio KPIs, TIME assessment, technology risks
  analyze coverage               capability coverage (gaps / redundancies)
  analyze products               product lifecycle alerts (EoL / EoSu / blacklist / reminders)
  analyze impact <applicationId> impact analysis of an application
  export archimate [file]        ArchiMate 3.1 exchange format (stdout or file)

Import / export (CSV, XLSX - the format follows the file extension):
  export <Set|all> <file>        write a set (csv/xlsx) or all sets (xlsx, one sheet per set)
         [--headers names]       technical field names instead of labels as column headers
         [--sep ';']             CSV separator (default ',')
  import <Set|all> <file>        upsert by ID: existing elements are updated with the columns present,
         [--dry-run]             new ones created; rows that fail are listed (exit code 1)
  seed                           load the demo architecture into an empty repository

Options:
  --json                         machine readable output
  --remote URL                   operate on a running server, e.g. http://localhost:8080/odata/v4/eam
  --token TOKEN                  bearer token for --remote
  --user NAME                    act as repository user NAME (checked against its roles / permissions);
                                 without --user the local operator is administrator

Access management:
  rights [userName]              effective rights of a user (default: --user or the local operator)

Comments (running journal of every element):
  comments <Set> <id>            comments of an element, newest first
  comment <Set> <id> <text>      add a comment (author: --user or the local operator)
  comment delete <commentId>     delete a comment (author, or delete permission on the set)

Reporting:
  report run <id>                run a report definition (table, group summary)
  report export <id> <file>      export as .xlsx, .csv or .pdf (format from the extension)
  reportbook export <id> <file>  export all reports of a report book (.xlsx or .pdf)

Tenants (Mandanten) - every command works on one tenant: --tenant ID (or EAM_TENANT), default "default":
  tenants                        list tenants (system administrator)
  tenants create <id> name=N [description=D] [zoneId=Z] [--seed] [--admin USER] [--admin-email MAIL]
  tenants update <id> field=value ...   (name, description, status=Active|Suspended, zoneId)
  tenants delete <id>            final backup, then remove the tenant and its data

Backup & restore (current tenant):
  backup list                    stored backups, newest first
  backup create [comment]        take a backup
  backup restore <id|file> [--check]   check (checksum, format, test load) and restore; a safety backup
                                 of the current state is taken first
  backup download <id> <file>    copy a stored backup to a file
  backup delete <id>             delete a stored backup
  backup run                     scheduled backup of all active tenants (with retention), e.g. from cron

Search:
  search <text> [--top N]        central search over all sets (name, id, descriptions, free text)

Sets: Applications, ApplicationGroups, Products, ProductGroups, BusinessCapabilities, BusinessProcesses,
      BusinessData, ITComponents, InformationFlows, Organizations, Projects, ServiceProductGroups,
      StrategicGuidelines, ServiceCapabilities, MeasureGroups, Measures, ArchitecturePrinciples,
      ArchitectureGuidelines, ReferenceArchitectures, ArchitectureDocuments, SubProjects, WorkPackages,
      Enterprises, Members, ITProcesses, ProcessSteps, ProcessKpis, ProtectionRequirements, SecurityRisks,
      SecurityControls, Reports, ReportBooks, Users, Roles, Permissions`;

struct CliOptions {
	string[] positional;
	string[string] options;
	bool json;

	static CliOptions parse(string[] args) {
		CliOptions o;
		for (size_t i = 0; i < args.length; i++) {
			auto a = args[i];
			if (a == "--json") o.json = true;
			else if (a.startsWith("--")) {
				auto eq = a.indexOf('=');
				if (eq > 0) o.options[a[2 .. eq]] = a[eq + 1 .. $];
				else if (i + 1 < args.length && !args[i + 1].startsWith("--")) o.options[a[2 .. $]] = args[++i];
				else o.options[a[2 .. $]] = "";
			} else o.positional ~= a;
		}
		return o;
	}

	string opt(string name, string def = null) { return options.get(name, def); }
}

/// Entry point: `args` without the program name. Returns the process exit code.
/// Recorded as `modifiedBy` of CLI changes.
private string cliActor() { return s_cliUser.length ? s_cliUser : localUserName() ~ "@cli"; }
private void cliActor(string v) { s_cliUser = v; }
private string s_cliUser;

private IEamPlatform s_platform;
private AccessSubjectDto s_subject;
private string s_tenant;

int runCli(string[] args, IEamPlatform platform) {
	auto o = CliOptions.parse(args);
	if (o.positional.length == 0 || o.positional[0].among("help", "-h")) {
		writeln(cliUsage);
		return 0;
	}
	try {
		if (auto remote = "remote" in o.options)
			return runRemote(o, new ODataClient(*remote, o.opt("token").length ? "Bearer " ~ o.opt("token") : null));
		// the local operator is (system) administrator; --user acts as a repository user of the tenant
		import std.process : environment;
		s_platform = platform;
		s_subject = AccessSubjectDto(localUserName(), "", true, true, "");
		if (auto user = "user" in o.options) {
			cliActor = *user ~ "@cli";
			s_subject = AccessSubjectDto(*user, "", false, false, "");
		}
		s_tenant = platform.resolveTenant(s_subject, o.opt("tenant", environment.get("EAM_TENANT", "")));
		auto uc = platform.tenantUseCases(s_tenant);
		if ("user" in o.options) uc = uc.access.useCasesFor(s_subject);
		return runLocal(o, uc);
	} catch (Exception e) {
		stderr.writefln("error (%s): %s", classify(e).code, e.msg);
		return 1;
	}
}

private bool among(string s, string[] values...) { return values.canFind(s); }

private int runLocal(ref CliOptions o, IEamUseCases uc) {
	auto p = o.positional;
	auto cmd = p[0];
	switch (cmd) {
		case "sets":
			static foreach (S; EamDtoSets) {
				try writefln("%-22s %3s  %s", S.setName, manage!S(uc).count, S.label);
				catch (AccessDeniedException) writefln("%-22s %3s  %s", S.setName, "-", S.label ~ " (no read permission)");
			}
			return 0;
		case "tenants":
			return tenantCommand(o);
		case "comments":
			needArgs(p, 3, cmd);
			Json[] rows;
			foreach (c; uc.comments.list(p[1], p[2], s_subject.userName))
				rows ~= Json(["date": Json(c.createdAt.length >= 16 ? c.createdAt[0 .. 16].replace("T", " ") : c.createdAt),
					"author": Json(c.createdBy), "comment": Json(c.text), "id": Json(c.id)]);
			printRows(o, rows, ["date", "author", "comment", "id"]);
			return 0;
		case "comment":
			needArgs(p, 3, cmd);
			if (p[1] == "delete") {
				uc.comments.remove(p[2], s_subject.userName);
				writefln("Comment %s deleted", p[2]);
				return 0;
			}
			needArgs(p, 4, cmd);
			auto added = uc.comments.add(p[1], p[2], p[3 .. $].join(" "), s_subject.userName);
			writefln("Comment %s added to %s('%s')", added.id, p[1], p[2]);
			return 0;
		case "report", "reportbook":
			return reportCommand(o, uc);
		case "backup":
			return backupCommand(o);
		case "rights":
			auto who = p.length > 1 ? p[1] : o.opt("user");
			auto subject = who.length ? AccessSubjectDto(who, "", false) : AccessSubjectDto(localUserName(), "", true);
			auto r = uc.access.rightsFor(subject);
			if (o.json) { writeln(serializeToPrettyJson(r)); return 0; }
			writefln("%s (%s) - %s%s", r.displayName, r.source, r.summary, r.roles.length ? " - roles: " ~ r.roles.join(", ") : "");
			Json[] rows;
			foreach (s; r.sets)
				rows ~= Json(["set": Json(s.setName), "read": Json(s.read ? "x" : ""), "create": Json(s.create ? "x" : ""),
					"update": Json(s.update ? "x" : ""), "delete": Json(s.remove ? "x" : "")]);
			printRows(o, rows, ["set", "read", "create", "update", "delete"]);
			return 0;
		case "fields":
			needArgs(p, 2, cmd);
			auto info = describeSet(p[1]);
			if (info is null) throw new Exception("Unknown set '" ~ p[1] ~ "'. Run 'eam sets'.");
			if (o.json) { writeln(serializeToPrettyJson(info.fields)); return 0; }
			Json[] rows;
			foreach (f; info.fields) {
				auto flags = (f.required ? "required " : "") ~ (f.readOnly ? "read-only " : "")
					~ (f.reference.length ? "-> " ~ f.reference : "");
				rows ~= Json(["name": Json(f.name), "label": Json(f.label), "type": Json(f.type), "group": Json(f.group),
					"flags": Json(flags), "values": Json(f.choices.join("|"))]);
			}
			printRows(o, rows, ["name", "label", "type", "group", "flags", "values"]);
			return 0;
		case "list", "show", "create", "update", "delete":
			needArgs(p, cmd == "list" || cmd == "create" ? 2 : 3, cmd);
			static foreach (S; EamDtoSets)
				if (p[1] == S.setName) return elementCommand!S(o, uc);
			throw new Exception("Unknown set '" ~ p[1] ~ "'. Run 'eam sets'.");
		case "analyze":
			needArgs(p, 2, cmd);
			return analyze(o, uc);
		case "export":
			needArgs(p, 2, cmd);
			if (p[1] == "archimate") {
				auto xml = uc.archimate.exportModel();
				if (p.length > 2) { write(p[2], xml); writefln("ArchiMate model written to %s", p[2]); }
				else writeln(xml);
				return 0;
			}
			needArgs(p, 3, cmd);
			return exportTable(o, uc, p[1], p[2]);
		case "import":
			needArgs(p, 3, cmd);
			return importTable(o, uc, p[1], p[2]);
		case "seed":
			writefln("%s elements created", uc.seeder.seed());
			return 0;
		case "search":
			needArgs(p, 2, cmd);
			auto hits = uc.search.search(p[1 .. $].join(" "), o.opt("top", "25").to!size_t);
			Json[] rows;
			foreach (h; hits)
				rows ~= Json(["set": Json(h.setName), "id": Json(h.id), "name": Json(h.name), "score": Json(h.score),
					"match": Json(h.matchedField.length ? h.matchedField ~ ": " ~ h.snippet : "")]);
			printRows(o, rows, ["set", "id", "name", "score", "match"]);
			if (!o.json) writefln("%s hit(s)", hits.length);
			return 0;
		default:
			throw new Exception("Unknown command '" ~ cmd ~ "'. Run 'eam help'.");
	}
}

/// `export <Set|all> <file.csv|file.xlsx>`: the format follows the file extension.
private int exportTable(ref CliOptions o, IEamUseCases uc, string set, string file) {
	auto codec = codecFor(file, cliSeparator(o));
	auto technical = o.opt("headers", "labels") == "names";
	auto sheets = set == "all" ? uc.transfer.exportAll(technical) : [uc.transfer.exportSet(set, technical)];
	std.file.write(file, codec.encode(sheets));
	size_t rows;
	foreach (t; sheets) rows += t.rows.length;
	writefln("%s element(s) of %s set(s) written to %s", rows, sheets.length, file);
	return 0;
}

/// `import <Set|all> <file> [--dry-run]`: upsert by ID; exit code 1 when rows failed.
private int importTable(ref CliOptions o, IEamUseCases uc, string set, string file) {
	auto data = cast(const(ubyte)[]) std.file.read(file);
	auto sheets = codecForContent(data).decode(data);
	auto dry = "dry-run" in o.options || "dryRun" in o.options;
	auto actor = cliActor;
	auto results = set == "all" ? uc.transfer.importAll(sheets, actor, dry)
		: [uc.transfer.importSet(set, pickSheet(sheets, set), actor, dry)];
	if (o.json) { writeln(serializeToPrettyJson(results)); return results.any!(r => r.failed > 0) ? 1 : 0; }
	Json[] rows, issues;
	foreach (r; results) {
		rows ~= Json(["set": Json(r.setName), "rows": Json(r.rows), "created": Json(r.created), "updated": Json(r.updated),
			"unchanged": Json(r.unchanged), "failed": Json(r.failed)]);
		foreach (i; r.issues)
			issues ~= Json(["set": Json(r.setName), "row": Json(i.row), "id": Json(i.id), "severity": Json(i.severity),
				"field": Json(i.field), "message": Json(i.message)]);
	}
	printRows(o, rows, ["set", "rows", "created", "updated", "unchanged", "failed"]);
	if (issues.length) printRows(o, issues, ["set", "row", "id", "severity", "field", "message"]);
	if (dry) writeln("Dry run - nothing was saved.");
	return results.any!(r => r.failed > 0) ? 1 : 0;
}

private char cliSeparator(ref CliOptions o) {
	auto s = o.opt("sep", ",");
	return s == ";" || s == "semicolon" ? ';' : s == "tab" || s == "\t" ? '\t' : ',';
}

private int elementCommand(alias S)(ref CliOptions o, IEamUseCases uc) {
	auto p = o.positional;
	auto m = manage!S(uc);
	switch (p[0]) {
		case "list":
			Json[] rows;
			foreach (d; m.list) rows ~= dtoToJson(d);
			printRows(o, applyQuery(rows, queryFromOptions(o)).items, defaultColumns!S);
			return 0;
		case "show":
			printOne(o, dtoToJson(m.get(p[2])), fieldNames!(S.Dto)());
			return 0;
		case "create":
			S.Dto dto;
			dto.applyStringValues(assignments(p[2 .. $]));
			auto created = m.create(dto, cliActor);
			if (o.json) writeln(dtoToJson(created).toPrettyString());
			else writefln("Created %s('%s')", S.setName, created.id);
			return 0;
		case "update":
			auto dto = m.get(p[2]);
			dto.applyStringValues(assignments(p[3 .. $]));
			auto updated = m.update(p[2], dto, cliActor);
			if (o.json) writeln(dtoToJson(updated).toPrettyString());
			else writefln("Updated %s('%s')", S.setName, updated.id);
			return 0;
		case "delete":
			m.remove(p[2]);
			writefln("Deleted %s('%s')", S.setName, p[2]);
			return 0;
		default: assert(0);
	}
}

private int analyze(ref CliOptions o, IEamUseCases uc) {
	auto p = o.positional;
	switch (p[1]) {
		case "portfolio":
			auto r = uc.analysis.portfolio();
			if (o.json) { writeln(serializeToPrettyJson(r)); return 0; }
			writefln("Generated:                 %s", r.generatedAt);
			foreach (c; r.counts) writefln("  %-22s %s", c.kind, c.count);
			writefln("Operational applications:  %s (%s mission critical)", r.operationalApplications, r.missionCriticalApplications);
			writefln("Annual cost (operational): %.2f", r.totalAnnualCost);
			writefln("Capability gaps:           %s, redundancies: %s", r.capabilityGaps, r.capabilityRedundancies);
			writeln("\nTIME assessment:");
			printRows(o, r.timeAssessments.map!(t => serializeToJson(t)).array,
				["applicationName", "businessValue", "technicalFit", "current", "recommended", "deviates"]);
			writefln("Product alerts:            %s (%s critical)", r.productAlertCount, r.criticalProductAlerts);
			writeln("\nTechnology risks:");
			printRows(o, r.technologyRisks.map!(t => serializeToJson(t)).array,
				["applicationName", "componentName", "endOfSupportDate", "reason"]);
			return 0;
		case "coverage":
			printRows(o, uc.analysis.coverage().map!(t => serializeToJson(t)).array,
				["capabilityName", "level", "supportingApplicationIds", "gap", "redundant"]);
			return 0;
		case "products":
			printRows(o, uc.analysis.productAlerts().map!(t => serializeToJson(t)).array,
				["severity", "kind", "productName", "productVersion", "date", "message", "applicationIds"]);
			return 0;
		case "impact":
			needArgs(p, 3, "analyze impact");
			printOne(o, serializeToJson(uc.analysis.impact(p[2])));
			return 0;
		default:
			throw new Exception("Unknown analysis '" ~ p[1] ~ "' (portfolio|coverage|products|impact)");
	}
}

// ---------------------------------------------------------------- remote mode

private int runRemote(ref CliOptions o, ODataClient client) {
	auto p = o.positional;
	needArgs(p, 2, p[0]);
	auto set = p[1];
	if (!allSetNames.canFind(set)) throw new Exception("Unknown set '" ~ set ~ "'");
	string entity(string id) { return set ~ "('" ~ encodeKey(id) ~ "')"; }
	switch (p[0]) {
		case "list":
			string[] q;
			foreach (k; ["filter", "orderby", "top"])
				if (auto v = k in o.options) q ~= "$" ~ k ~ "=" ~ urlEncodeQuery(*v);
			auto rows = client.get(set ~ (q.length ? "?" ~ q.join("&") : ""))["value"];
			Json[] arr;
			foreach (r; rows) arr ~= r;
			printRows(o, arr, ["id", "name"]);
			return 0;
		case "show":
			needArgs(p, 3, "show");
			printOne(o, client.get(entity(p[2])));
			return 0;
		case "create":
			auto created = client.post(set, assignmentsToJson(p[2 .. $]));
			writefln("Created %s('%s')", set, created["id"].get!string);
			return 0;
		case "update":
			needArgs(p, 3, "update");
			client.patch(entity(p[2]), assignmentsToJson(p[3 .. $]));
			writefln("Updated %s('%s')", set, p[2]);
			return 0;
		case "delete":
			needArgs(p, 3, "delete");
			client.remove(entity(p[2]));
			writefln("Deleted %s('%s')", set, p[2]);
			return 0;
		default:
			throw new Exception("Command '" ~ p[0] ~ "' is not available with --remote");
	}
}

private string encodeKey(string id) {
	import std.array : replace;
	import vibe.textfilter.urlencode : urlEncode;
	return urlEncode(id.replace("'", "''"));
}

private string urlEncodeQuery(string v) {
	import vibe.textfilter.urlencode : urlEncode;
	return urlEncode(v);
}

/// Remote values are sent as JSON; numbers / booleans / arrays are detected heuristically.
private Json assignmentsToJson(string[] items) {
	auto j = Json.emptyObject;
	foreach (k, v; assignments(items)) {
		if (v.canFind(",")) j[k] = Json(v.split(",").map!(s => Json(s)).array);
		else if (v == "true" || v == "false") j[k] = Json(v == "true");
		else {
			try j[k] = Json(v.to!long);
			catch (Exception) {
				try j[k] = Json(v.to!double); catch (Exception) j[k] = Json(v);
			}
		}
	}
	return j;
}

// ---------------------------------------------------------------- helpers

private string[string] assignments(string[] items) {
	string[string] r;
	foreach (it; items) {
		auto eq = it.indexOf('=');
		if (eq <= 0) throw new Exception("Expected field=value, got '" ~ it ~ "'");
		r[it[0 .. eq]] = it[eq + 1 .. $];
	}
	return r;
}

private QueryOptions queryFromOptions(ref CliOptions o) {
	QueryOptions q;
	q.filter = o.opt("filter");
	q.orderby = o.opt("orderby");
	q.search = o.opt("search");
	if (auto t = "top" in o.options) q.top = (*t).to!long;
	return q;
}

/// id + the @ListColumn fields of the set (at most 7 columns for terminal width).
private string[] defaultColumns(alias S)() {
	string[] cols = ["id"];
	foreach (f; describeFields!S())
		if (f.listColumn && cols.length < 7) cols ~= f.name;
	return cols;
}

private void needArgs(string[] p, size_t n, string cmd) {
	if (p.length < n) throw new Exception("Missing arguments for '" ~ cmd ~ "'. Run 'eam help'.");
}

private string cell(Json v) {
	if (v.type == Json.Type.string) return v.get!string;
	if (v.type == Json.Type.null_ || v.type == Json.Type.undefined) return "";
	if (v.type == Json.Type.array) return v.byValue.map!(e => cell(e)).join(",");
	return v.toString();
}

private void printOne(ref CliOptions o, Json j, string[] order = null) {
	if (o.json) { writeln(j.toPrettyString()); return; }
	if (order.length) {
		foreach (k; order) writefln("%-26s %s", k, cell(j[k]));
		return;
	}
	foreach (string k, v; j)
		if (!k.startsWith("@")) writefln("%-26s %s", k, cell(v));
}

void printRows(ref CliOptions o, Json[] rows, string[] defaultCols) {
	if (o.json) { writeln(Json(rows).toPrettyString()); return; }
	auto cols = o.opt("fields").length ? o.opt("fields").split(",") : defaultCols;
	size_t[] width = cols.map!(c => c.length).array;
	foreach (r; rows)
		foreach (i, c; cols) width[i] = max(width[i], cell(r[c]).length > 40 ? 40 : cell(r[c]).length);
	string line(string[] values) {
		string s;
		foreach (i, v; values) s ~= (v.length > 40 ? v[0 .. 37] ~ "..." : v).leftJustify(width[i]) ~ "  ";
		return s;
	}
	writeln(line(cols));
	writeln(line(width.map!(w => '-'.repeat(w).array.to!string).array));
	foreach (r; rows) writeln(line(cols.map!(c => cell(r[c])).array));
	writefln("(%s rows)", rows.length);
}


// ---------------------------------------------------------------- tenants and backups

private int tenantCommand(ref CliOptions o) {
	auto p = o.positional;
	if (p.length == 1) {
		Json[] rows;
		foreach (t; s_platform.listTenants(s_subject))
			rows ~= Json(["id": Json(t.id), "name": Json(t.name), "status": Json(t.status), "zone": Json(t.zoneId),
				"elements": Json(t.elements), "backups": Json(t.backups), "lastBackup": Json(t.lastBackupAt), "data": Json(t.dataLocation)]);
		printRows(o, rows, ["id", "name", "status", "zone", "elements", "backups", "lastBackup", "data"]);
		return 0;
	}
	needArgs(p, 3, "tenants " ~ p[1]);
	auto values = keyValues(p[3 .. $]);
	switch (p[1]) {
		case "create":
			TenantCreateDto r;
			r.tenant.id = p[2];
			r.tenant.name = values.get("name", p[2]);
			r.tenant.description = values.get("description", "");
			r.tenant.zoneId = values.get("zoneId", "");
			r.seedDemoData = ("seed" in o.options) !is null;
			r.adminUserName = o.opt("admin");
			r.adminEmail = o.opt("admin-email");
			auto t = s_platform.createTenant(r, s_subject);
			writefln("Tenant '%s' created (%s elements, data: %s)", t.id, t.elements, t.dataLocation);
			return 0;
		case "update":
			auto t = s_platform.getTenant(p[2], s_subject);
			foreach (k, v; values) switch (k) {
				case "name": t.name = v; break;
				case "description": t.description = v; break;
				case "status": t.status = v; break;
				case "zoneId": t.zoneId = v; break;
				default: throw new Exception("Unknown tenant field '" ~ k ~ "'");
			}
			t = s_platform.updateTenant(p[2], t, s_subject);
			writefln("Tenant '%s' updated (%s)", t.id, t.status);
			return 0;
		case "delete":
			s_platform.deleteTenant(p[2], s_subject);
			writefln("Tenant '%s' deleted - its backups are kept", p[2]);
			return 0;
		default:
			throw new Exception("Unknown tenants command '" ~ p[1] ~ "'");
	}
}

private int backupCommand(ref CliOptions o) {
	auto p = o.positional;
	needArgs(p, 2, "backup");
	switch (p[1]) {
		case "list":
			Json[] rows;
			foreach (b; s_platform.listBackups(s_tenant, s_subject))
				rows ~= Json(["id": Json(b.id), "created": Json(b.createdAt), "by": Json(b.createdBy), "kind": Json(b.kind),
					"elements": Json(b.elements), "bytes": Json(b.sizeBytes), "comment": Json(b.comment)]);
			printRows(o, rows, ["id", "created", "by", "kind", "elements", "bytes", "comment"]);
			return 0;
		case "create":
			auto b = s_platform.createBackup(s_tenant, p[2 .. $].join(" "), s_subject);
			writefln("Backup %s of tenant '%s' written (%s elements, %s bytes)", b.id, s_tenant, b.elements, b.sizeBytes);
			return 0;
		case "restore":
			needArgs(p, 3, "backup restore");
			immutable check = ("check" in o.options) !is null;
			auto r = std.file.exists(p[2])
				? s_platform.restoreUpload(s_tenant, cast(const(ubyte)[]) std.file.read(p[2]), check, true, s_subject)
				: s_platform.restoreBackup(s_tenant, p[2], check, s_subject);
			if (o.json) { writeln(serializeToPrettyJson(r)); return 0; }
			foreach (w; r.warnings) writefln("warning: %s", w);
			writefln("%s: backup of tenant '%s' from %s, %s elements%s", check ? "Check passed" : "Restored",
				r.sourceTenant, r.backupCreatedAt, r.elements, r.safetyBackupId.length ? " - safety backup " ~ r.safetyBackupId : "");
			return 0;
		case "download":
			needArgs(p, 4, "backup download");
			std.file.write(p[3], s_platform.backupFile(s_tenant, p[2], s_subject));
			writefln("Backup %s written to %s", p[2], p[3]);
			return 0;
		case "delete":
			needArgs(p, 3, "backup delete");
			s_platform.deleteBackup(s_tenant, p[2], s_subject);
			writefln("Backup %s deleted", p[2]);
			return 0;
		case "run":
			if (!s_subject.systemAdministrator) throw new AccessDeniedException("", "Scheduled backups require a system administrator");
			writefln("%s tenant backup(s) written", s_platform.runScheduledBackups());
			return 0;
		default:
			throw new Exception("Unknown backup command '" ~ p[1] ~ "'");
	}
}

private string[string] keyValues(string[] args) {
	import std.string : indexOf;
	string[string] r;
	foreach (a; args) {
		auto eq = a.indexOf('=');
		if (eq <= 0) throw new Exception("Expected field=value, got '" ~ a ~ "'");
		r[a[0 .. eq]] = a[eq + 1 .. $];
	}
	return r;
}


// ---------------------------------------------------------------- reporting

private int reportCommand(ref CliOptions o, IEamUseCases uc) {
	import std.path : extension;
	import neko.eam.presentation.http.reports : renderReport;
	auto p = o.positional;
	needArgs(p, 3, p[0]);
	immutable book = p[0] == "reportbook";
	auto results = book ? uc.reporting.runBook(p[2], cliActor) : [uc.reporting.run(p[2], cliActor)];
	switch (p[1]) {
		case "run":
			if (o.json) { writeln(serializeToPrettyJson(results)); return 0; }
			foreach (r; results) {
				writefln("%s  (%s, %s rows%s)", r.name, r.setLabel, r.totalCount, r.filter.length ? ", filter: " ~ r.filter : "");
				Json[] rows;
				foreach (row; r.rows) {
					auto j = Json.emptyObject;
					foreach (i, c; r.columns) j[c.label] = row[i];
					rows ~= j;
				}
				printRows(o, rows, r.columns.map!(c => c.label).array);
				if (r.groups.length) {
					Json[] g;
					foreach (x; r.groups)
						g ~= Json([r.groupLabel: Json(x.value), "Count": Json(x.count), "Sum": Json(r.sumField.length ? format("%.2f", x.sum) : "")]);
					printRows(o, g, [r.groupLabel, "Count"] ~ (r.sumField.length ? ["Sum"] : null));
				}
				writeln();
			}
			return 0;
		case "export":
			needArgs(p, 4, p[0] ~ " export");
			auto fmt = p[3].extension.length > 1 ? p[3].extension[1 .. $] : "xlsx";
			auto title = book ? uc.reportBooks.get(p[2]).name : results[0].name;
			std.file.write(p[3], renderReport(fmt, title, results, o.opt("sep", ",") == ";" ? ';' : ','));
			writefln("%s report(s) written to %s", results.length, p[3]);
			return 0;
		default:
			throw new Exception("Unknown " ~ p[0] ~ " command '" ~ p[1] ~ "'");
	}
}
