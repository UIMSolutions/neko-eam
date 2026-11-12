/// Integration tests across all layers (run with `dub test` / `dub test -c unittest`).
module integration_test;

import neko.eam.composition;
import neko.eam.ports;
import neko.eam.domain.exceptions;

unittest {
	auto c = EamContainer.inMemory();
	auto uc = c.useCases;
	assert(uc.seeder.seed() > 20);
	assert(uc.seeder.seed() == 0, "seeding must be idempotent");

	// referential integrity: unknown owner organisation
	ApplicationDto app;
	app.name = "Test";
	app.ownerOrganizationId = "does-not-exist";
	bool failed;
	try uc.applications.create(app); catch (ReferentialIntegrityException) failed = true;
	assert(failed);

	// create / update / delete
	app.ownerOrganizationId = "org-it";
	auto created = uc.applications.create(app);
	assert(created.id.length && created.createdAt.length);
	created.businessValue = 1; created.technicalFit = 1;
	auto updated = uc.applications.update(created.id, created);
	assert(updated.businessValue == 1);
	uc.applications.remove(created.id);
	failed = false;
	try uc.applications.get(created.id); catch (EntityNotFoundException) failed = true;
	assert(failed);

	// still referenced elements cannot be deleted
	failed = false;
	try uc.applications.remove("app-crm"); catch (ReferentialIntegrityException) failed = true;
	assert(failed);

	// analysis
	auto report = uc.analysis.portfolio();
	assert(report.technologyRiskCount >= 2);   // legacy CRM + BI on Oracle 11g / Java 8
	auto impact = uc.analysis.impact("app-crm");
	assert(impact.dependentApplicationIds.length == 2);
	assert(uc.archimate.exportModel().length > 1000);

	// product catalogue: derived reminder dates, actor, blacklist rule
	ProductDto prd;
	prd.name = "PostgreSQL";
	prd.productVersion = "17";
	prd.productGroupId = "pg-db";
	prd.endOfLife = "2029-11-08";
	prd.eolReminderDays = 90;
	auto savedPrd = uc.products.create(prd, "jdoe");
	assert(savedPrd.eolReminderDate == "2029-08-10" && savedPrd.modifiedBy == "jdoe");
	savedPrd.isBlacklisted = true;
	savedPrd.approvalStatus = "Approved";
	failed = false;
	try uc.products.update(savedPrd.id, savedPrd); catch (ValidationException) failed = true;
	assert(failed);
	failed = false;
	try uc.productGroups.remove("pg-db"); catch (ReferentialIntegrityException) failed = true;
	assert(failed, "product groups with products cannot be deleted");

	// application groups roll up the products of their subtree
	auto before = uc.applicationGroups.get("ag-customer").totalUsedProducts;
	auto crm = uc.applications.get("app-crm");
	crm.usedProductIds = [savedPrd.id];
	assert(uc.applications.update("app-crm", crm).totalUsedProducts == 1);
	assert(uc.applicationGroups.get("ag-customer").totalUsedProducts == before + 1);
	assert(uc.applicationGroups.get("ag-finance").totalUsedProducts == 2);

	// product lifecycle alerts
	auto alerts = uc.analysis.productAlerts();
	import std.algorithm : canFind;
	assert(alerts.canFind!(a => a.productId == "prd-oracle-11" && a.kind == "EndOfLife" && a.severity == "Critical"));
	assert(alerts.canFind!(a => a.productId == "prd-winrar-6" && a.kind == "Blacklisted"));
	assert(uc.analysis.portfolio().productAlertCount == alerts.length);

	// hierarchy paths, creator and new entity kinds
	auto ops = uc.organizations.get("org-it-ops");
	assert(ops.hierarchyPath == "ACME Group / Group IT / IT Operations" && ops.createdBy == "seed");
	assert(uc.capabilities.get("cap-crm").hierarchyPath == "Customer Management / Customer Relationship Management");
	assert(uc.businessProcesses.get("bp-r2r-close").hierarchyPath == "Record to Report / Period End Closing");
	assert(uc.serviceProductGroups.get("spg-support").hierarchyPath == "IT Service Catalogue / Support Services");
	ops.contact = "ops-hotline@acme.example";
	auto updatedOps = uc.organizations.update("org-it-ops", ops, "jdoe");
	assert(updatedOps.createdBy == "seed" && updatedOps.modifiedBy == "jdoe");
	failed = false;
	try uc.flows.remove("if-s4-bi"); catch (ReferentialIntegrityException) failed = true;
	assert(failed, "flows referenced by business data cannot be deleted");
	BusinessDataDto bd;
	bd.name = "Contract";
	bd.dpiaRating = "High";
	failed = false;
	try uc.businessData.create(bd); catch (ValidationException e) failed = e.field == "ownerOrganizationId";
	assert(failed, "high DPIA rating requires an owner");

	// central search
	auto hits = uc.search.search("customer");
	assert(hits.length > 5 && hits[0].name == "Customer", "exact name match ranks first");
	assert(hits.canFind!(h => h.setName == "BusinessData" && h.id == "bd-customer"));
	assert(uc.search.search("acme group it").canFind!(h => h.id == "org-it-ops"), "terms are AND-combined over all text fields");
	assert(uc.search.search("   ").length == 0);
	assert(uc.search.search("a", 3).length == 3);
}


// CSV / XLSX import and export through the use cases
unittest {
	import std.algorithm : canFind, countUntil, filter, map, sum;
	import std.array : array;
	import neko.eam.infrastructure.formats;
	import neko.eam.application.usecases.transferelements : cellValues;

	auto source = EamContainer.inMemory().useCases;
	source.seeder.seed();

	// full round trip: export every set as one workbook, import it into an empty repository
	auto xlsx = new XlsxCodec;
	auto bytes = xlsx.encode(source.transfer.exportAll());
	auto target = EamContainer.inMemory().useCases;
	auto results = target.transfer.importAll(xlsx.decode(bytes), "importer");
	assert(results.length == EamDtoSets.length);
	foreach (r; results) assert(r.failed == 0 && r.created == r.rows, r.setName ~ ": " ~ (r.issues.length ? r.issues[0].message : ""));
	static foreach (S; EamDtoSets) {{
		auto a = manage!S(source).list, b = manage!S(target).list;
		assert(a.length == b.length, S.setName);
		foreach (x; a) {
			auto y = manage!S(target).get(x.id);
			auto va = cellValues(x), vb = cellValues(y);
			foreach (k, v; va)
				if (k != "createdAt" && k != "modifiedAt" && k != "createdBy" && k != "modifiedBy")
					assert(vb[k] == v, S.setName ~ "." ~ k ~ ": " ~ v ~ " != " ~ vb[k]);
		}
		assert(manage!S(target).list[0].createdBy == "importer");
	}}
	// importing the same file again changes nothing
	assert(target.transfer.importAll(xlsx.decode(bytes), "importer").map!(r => r.unchanged).sum
		== results.map!(r => r.created).sum);

	// CSV of one set with labels, German conventions, a forward reference and errors
	auto csv = new CsvCodec;
	auto table = csv.decode(cast(const(ubyte)[])
		("ID;Name;Parent Organization;Status;Start Date;End Date;Total Provided Support Services;Unknown\r\n"
		~ "org-child;Child Unit;org-new;inactive;01.02.2020;;3;x\r\n"
		~ "org-new;New Unit;org-group;Active;2020-01-01;;;\r\n"
		~ "org-bad;Bad Unit;;Active;2021-01-01;2020-01-01;;\r\n"
		~ "org-nan;NaN Unit;;Active;;;many;\r\n"
		~ ";;;;;;;\r\n"
		~ "org-loop;Loop Unit;does-not-exist;Active;;;;\r\n"))[0];
	auto before = source.organizations.count;
	auto dry = source.transfer.importSet("Organizations", table, "jdoe", true);
	assert(dry.dryRun && dry.created == 2 && dry.failed == 3 && source.organizations.count == before, "dry run saves nothing");
	auto r = source.transfer.importSet("organizations", table, "jdoe");
	assert(r.rows == 5 && r.created == 2 && r.failed == 3);
	assert(r.issues.canFind!(i => i.row == 1 && i.severity == "Warning"), "unknown column reported");
	assert(r.issues.canFind!(i => i.row == 4 && i.field == "endDate"));
	assert(r.issues.canFind!(i => i.row == 5 && i.field == "totalProvidedSupportServices"));
	assert(r.issues.canFind!(i => i.row == 7 && i.id == "org-loop"));
	auto child = source.organizations.get("org-child");
	assert(child.status == "Inactive" && child.startDate == "2020-02-01" && child.totalProvidedSupportServices == 3
		&& child.hierarchyPath == "ACME Group / New Unit / Child Unit" && child.createdBy == "jdoe");

	// partial update: only the columns in the file change
	auto update = TableDto("", ["id", "contact"], [], [["org-it", "new-desk@acme.example"]]);
	auto u = source.transfer.importSet("Organizations", update, "jdoe");
	assert(u.updated == 1 && u.issues.canFind!(i => i.field == "name" && i.severity == "Warning"));
	auto it = source.organizations.get("org-it");
	assert(it.contact == "new-desk@acme.example" && it.architect == "M. Weber" && it.modifiedBy == "jdoe");

	bool failed;
	try source.transfer.exportSet("Nope"); catch (ValidationException) failed = true;
	assert(failed);
}

/// IT landscape planning: strategic guidelines, service capabilities, measure groups and measures.
unittest {
	import std.algorithm : canFind;
	auto uc = EamContainer.inMemory().useCases;
	uc.seeder.seed();

	assert(uc.strategicGuidelines.get("sg-cloud-paas").hierarchyPath == "Cloud first / PaaS before IaaS");
	auto container = uc.serviceCapabilities.get("sc-container");
	assert(container.hierarchyPath == "Hosting & Operations / Container Platform" && container.maturityGap == 2);
	assert(uc.serviceCapabilities.get("sc-workplace").maturityGap == 0);

	// measure groups roll up the measures of their subtree (rejected / cancelled measures excluded)
	auto roadmap = uc.measureGroups.get("mg-roadmap");
	assert(roadmap.totalMeasures == 5 && roadmap.totalEstimatedCost == 1_500_000);
	auto cloud = uc.measureGroups.get("mg-cloud");
	assert(cloud.hierarchyPath == "IT Roadmap 2026-2028 / Cloud Transformation" && cloud.totalMeasures == 2);
	auto java = uc.measures.get("ms-java");
	java.estimatedCost = 100_000;
	uc.measures.update("ms-java", java, "planner");
	assert(uc.measureGroups.get("mg-roadmap").totalEstimatedCost == 1_520_000);

	// business rules
	bool failed;
	MeasureDto m;
	m.name = "Retire something";
	m.measureType = "Retire";
	try uc.measures.create(m); catch (ValidationException e) failed = e.field == "affectedApplicationIds";
	assert(failed, "retire measures name the affected elements");
	m.affectedApplicationIds = ["app-unknown"];
	failed = false;
	try uc.measures.create(m); catch (ReferentialIntegrityException) failed = true;
	assert(failed, "unknown applications are rejected");
	m.affectedApplicationIds = ["app-legacycrm"];
	m.status = "Completed";
	failed = false;
	try uc.measures.create(m); catch (ValidationException e) failed = e.field == "progress";
	assert(failed, "completed measures are at 100 %");
	StrategicGuidelineDto g;
	g.name = "API first";
	g.status = "Active";
	failed = false;
	try uc.strategicGuidelines.create(g); catch (ValidationException e) failed = e.field == "guidelineOwner";
	assert(failed, "active guidelines need an owner");
	ServiceCapabilityDto sc;
	sc.name = "Too mature";
	sc.targetMaturity = 7;
	failed = false;
	try uc.serviceCapabilities.create(sc); catch (ValidationException e) failed = e.field == "targetMaturity";
	assert(failed, "maturity is 1-5");

	// referential integrity across the planning objects
	failed = false;
	try uc.strategicGuidelines.remove("sg-eol"); catch (ReferentialIntegrityException) failed = true;
	assert(failed, "guidelines referenced by measures cannot be deleted");
	failed = false;
	try uc.measureGroups.remove("mg-legacy"); catch (ReferentialIntegrityException) failed = true;
	assert(failed, "measure groups with measures cannot be deleted");
	failed = false;
	try uc.components.remove("tc-oracle11"); catch (ReferentialIntegrityException) failed = true;
	assert(failed);

	// search and ArchiMate export include the planning objects
	assert(uc.search.search("Cloud first").canFind!(h => h.id == "sg-cloud" && h.setName == "StrategicGuidelines"));
	auto xml = uc.archimate.exportModel();
	assert(xml.canFind(`identifier="id-sg-cloud" xsi:type="Principle"`));
	assert(xml.canFind(`identifier="id-ms-k8s" xsi:type="WorkPackage"`));
}

/// Specifications: architecture principles, architecture guidelines, reference architectures, documents.
unittest {
	import std.algorithm : canFind;
	auto uc = EamContainer.inMemory().useCases;
	uc.seeder.seed();

	auto ra = uc.referenceArchitectures.get("ra-cloud-native-api");
	assert(ra.hierarchyPath == "Cloud-native Application / API Microservice" && ra.totalDocuments == 1);
	assert(uc.referenceArchitectures.get("ra-cloud-native").totalDocuments == 2);
	// derived review flag: approved documents past their next review date
	assert(uc.architectureDocuments.get("doc-adr-k8s").reviewOverdue);
	assert(!uc.architectureDocuments.get("doc-ra-cn").reviewOverdue);
	assert(!uc.architectureDocuments.get("doc-analytics-concept").reviewOverdue);

	bool failed;
	ArchitectureGuidelineDto g;
	g.name = "Everything via message bus";
	g.obligation = "Mandatory";
	try uc.architectureGuidelines.create(g); catch (ValidationException e) failed = e.field == "principleIds";
	assert(failed, "mandatory guidelines are derived from a principle");
	g.principleIds = ["ap-missing"];
	failed = false;
	try uc.architectureGuidelines.create(g); catch (ReferentialIntegrityException) failed = true;
	assert(failed, "unknown principles are rejected");
	ArchitectureDocumentDto d;
	d.name = "Approved without approver";
	d.status = "Approved";
	failed = false;
	try uc.architectureDocuments.create(d); catch (ValidationException e) failed = e.field == "approver";
	assert(failed);
	ArchitecturePrincipleDto p;
	p.name = "Approved without statement";
	p.status = "Approved";
	p.principleOwner = "Chief Architect";
	failed = false;
	try uc.architecturePrinciples.create(p); catch (ValidationException e) failed = e.field == "statement";
	assert(failed);

	failed = false;
	try uc.architecturePrinciples.remove("ap-api"); catch (ReferentialIntegrityException) failed = true;
	assert(failed, "principles used by guidelines cannot be deleted");
	failed = false;
	try uc.products.remove("prd-temurin-21"); catch (ReferentialIntegrityException) failed = true;
	assert(failed, "standard products of guidelines cannot be deleted");
	// removing a document updates the derived document count
	uc.architectureDocuments.remove("doc-adr-k8s");
	assert(uc.referenceArchitectures.get("ra-cloud-native").totalDocuments == 1);

	assert(uc.search.search("OpenAPI").canFind!(h => h.id == "ag-openapi"));
	auto xml = uc.archimate.exportModel();
	assert(xml.canFind(`identifier="id-ag-openapi" xsi:type="Constraint"`));
	assert(xml.canFind(`identifier="id-ag-containers" xsi:type="Requirement"`));
	assert(xml.canFind(`identifier="id-doc-ra-cn" xsi:type="Representation"`));
}

/// Project management: projects, sub projects and work packages.
unittest {
	import std.algorithm : canFind;
	import neko.eam.domain.types : todayIso;
	auto uc = EamContainer.inMemory().useCases;
	uc.seeder.seed();

	// roll-up: progress weighted by planned effort (40@100 + 60@60 + 50@20 + 20@0 + 30@0) / 200 = 43 %
	auto crm = uc.projects.get("prj-crm-consolidation");
	assert(crm.totalSubProjects == 3 && crm.totalWorkPackages == 5 && crm.plannedEffortDays == 200 && crm.progress == 43);
	auto mig = uc.subProjects.get("sp-crm-migration");
	assert(mig.hierarchyPath == "CRM Consolidation / Customer Data Migration");
	assert(mig.totalWorkPackages == 3 && mig.progress == 57, "nested sub projects are included");
	assert(uc.subProjects.get("sp-crm-quality").hierarchyPath == "CRM Consolidation / Customer Data Migration / Data Quality Cleansing");
	assert(uc.workPackages.get("wp-crm-load").delayed == (todayIso() > "2026-10-31"));
	assert(!uc.workPackages.get("wp-crm-analysis").delayed);

	// progress reported on a work package changes the project
	auto load = uc.workPackages.get("wp-crm-load");
	load.progress = 100;
	load.status = "Completed";
	uc.workPackages.update("wp-crm-load", load, "pm");
	assert(uc.projects.get("prj-crm-consolidation").progress == 63);
	assert(!uc.workPackages.get("wp-crm-load").delayed);

	bool failed;
	WorkPackageDto w;
	w.name = "Orphan";
	try uc.workPackages.create(w); catch (ValidationException e) failed = e.field == "projectId";
	assert(failed, "work packages belong to a project");
	w.projectId = "prj-bi-cloud";
	w.status = "InProgress";
	failed = false;
	try uc.workPackages.create(w); catch (ValidationException e) failed = e.field == "responsible";
	assert(failed);
	w.status = "NotStarted";
	w.predecessorIds = ["wp-missing"];
	failed = false;
	try uc.workPackages.create(w); catch (ReferentialIntegrityException) failed = true;
	assert(failed);
	failed = false;
	try uc.projects.remove("prj-bi-cloud"); catch (ReferentialIntegrityException) failed = true;
	assert(failed, "projects with sub projects / work packages cannot be deleted");
	failed = false;
	try uc.workPackages.remove("wp-crm-analysis"); catch (ReferentialIntegrityException) failed = true;
	assert(failed, "predecessors cannot be deleted");
	auto xml = uc.archimate.exportModel();
	assert(xml.canFind(`identifier="id-wp-crm-load" xsi:type="WorkPackage"`));
	assert(xml.canFind(`xsi:type="Triggering" source="id-wp-crm-analysis" target="id-wp-crm-cleansing"`));
}

/// Access management: users, roles and permissions control which sets may be read and changed.
unittest {
	import std.algorithm : all, any, canFind, map;
	import std.array : array;
	auto base = EamContainer.inMemory().useCases;
	base.seeder.seed();
	auto ac = base.access;
	AccessSubjectDto as(string user) { return AccessSubjectDto(user, "", false); }
	bool denied(scope void delegate() fn) {
		try fn(); catch (AccessDeniedException) return true;
		return false;
	}

	// administrators (XSUAA Admin scope / local operator) are unrestricted
	auto admin = ac.rightsFor(AccessSubjectDto("someone", "", true));
	assert(admin.unrestricted && admin.source == "administrator");
	assert(ac.useCasesFor(AccessSubjectDto("someone", "", true)) is base);

	// viewer: reads all architecture data, changes nothing, does not see access management
	auto viewer = ac.useCasesFor(as("s.yilmaz"));
	assert(viewer.applications.list.length == 5);
	assert(denied({ ApplicationDto a; a.name = "X"; viewer.applications.create(a); }));
	assert(denied({ viewer.products.remove("prd-winrar-6"); }));
	assert(denied({ viewer.users.list; }));
	assert(viewer.search.search("acme").all!(h => h.setName != "Users"), "users are not searchable without permission");
	auto sheets = viewer.transfer.exportAll();
	assert(sheets.length == EamDtoSets.length - 3 && !sheets.map!(t => t.name).canFind("Users"));
	assert(viewer.analysis.portfolio().operationalApplications > 0);
	assert(viewer.archimate.exportModel().length > 0);
	assert(denied({ viewer.seeder.seed(); }));

	// application owner + project manager (two roles): own sets editable, others read-only
	auto becker = ac.useCasesFor(as("J.Becker")); // user names are case-insensitive
	auto crm = becker.applications.get("app-crm");
	crm.stakeholder = "Sales Board";
	assert(becker.applications.update("app-crm", crm, "j.becker").stakeholder == "Sales Board");
	auto wp = becker.workPackages.get("wp-crm-training");
	wp.responsible = "J. Becker";
	becker.workPackages.update("wp-crm-training", wp, "j.becker");
	assert(denied({ auto p = becker.products.get("prd-k8s-131"); becker.products.update(p.id, p); }));
	// import: rows of sets without write permission fail, the others are imported
	TableDto t = { name: "Products", columns: ["ID", "Name"], rows: [["prd-k8s-131", "Kubernetes (renamed)"]] };
	auto res = becker.transfer.importSet("Products", t, "j.becker");
	assert(res.failed == 1 && res.issues[0].message.canFind("No permission"));
	assert(base.products.get("prd-k8s-131").name == "Kubernetes");

	// team member: only sees and updates work packages
	auto krueger = ac.useCasesFor(as("a.krueger"));
	assert(krueger.workPackages.list.length == 7);
	assert(denied({ krueger.applications.list; }));
	assert(denied({ krueger.analysis; }), "analyses need read access to applications");
	assert(denied({ WorkPackageDto w; w.name = "New"; w.projectId = "prj-bi-cloud"; krueger.workPackages.create(w); }));
	assert(krueger.search.search("migration").all!(h => h.setName == "WorkPackages"));
	auto rk = ac.rightsFor(as("a.krueger"));
	assert(rk.summary == "WorkPackages: RU" && rk.roles == ["Project Team Member"]);

	// e-mail match, disabled and unknown users
	assert(ac.rightsFor(AccessSubjectDto("x", "M.Weber@ACME.example", false)).userId == "usr-weber");
	auto former = ac.rightsFor(as("f.employee"));
	assert(former.source == "disabled user" && !former.sets.any!(s => s.read));
	auto unknown = ac.rightsFor(as("intruder"));
	assert(unknown.source == "unknown user" && !unknown.sets.any!(s => s.read));
	assert(denied({ ac.useCasesFor(as("intruder")).applications.list; }));

	// inactive roles grant nothing; the user page shows the effective rights
	auto weber = base.users.get("usr-weber");
	weber.roleIds = ["role-legacy"];
	base.users.update("usr-weber", weber);
	assert(ac.rightsFor(as("m.weber")).summary == "No access");
	assert(base.users.get("usr-becker").effectiveRights.canFind("Applications: RCUD"));
	assert(base.roles.get("role-viewer").totalUsers == 1 && base.permissions.get("perm-read-all").totalRoles == 8);

	// user names are unique; permissions need read for write; access management is not covered by "All"
	bool failed;
	UserDto dup;
	dup.name = "Copy"; dup.userName = "EAM.ADMIN";
	try base.users.create(dup); catch (ValidationException e) failed = e.field == "userName";
	assert(failed);
	auto architect = ac.rightsFor(as("eam.admin"));
	assert(architect.sets.canFind!(s => s.setName == "Users" && s.remove));
	PermissionDto bad;
	bad.name = "Write without read"; bad.canRead = false; bad.canUpdate = true;
	failed = false;
	try base.permissions.create(bad); catch (ValidationException e) failed = e.field == "canRead";
	assert(failed);

	// fresh installation without users: everybody may read (bootstrap), nobody but administrators may write
	auto fresh = EamContainer.inMemory().useCases;
	auto boot = fresh.access.rightsFor(as("first.user"));
	assert(boot.source == "bootstrap");
	auto bootUc = fresh.access.useCasesFor(as("first.user"));
	assert(bootUc.applications.list.length == 0);
	assert(denied({ ApplicationDto a; a.name = "X"; bootUc.applications.create(a); }));
	assert(denied({ bootUc.users.list; }));
}

/// Organisation structure: enterprises (legal entities), organisational units and their members.
unittest {
	import std.algorithm : canFind;
	import neko.eam.domain.types : todayIso;
	auto uc = EamContainer.inMemory().useCases;
	uc.seeder.seed();
	immutable bergerActive = todayIso() <= "2026-12-31"; // the external consultant's contract ends then

	// staffing of the units from their current members
	auto it = uc.organizations.get("org-it");
	assert(it.headOfUnit == "Markus Weber" && it.totalMembers == (bergerActive ? 2 : 1));
	assert(it.totalCapacity == (bergerActive ? 1.5 : 1.0));
	auto ops = uc.organizations.get("org-it-ops");
	assert(ops.headOfUnit == "Ralf Neumann" && ops.totalMembers == 3 && ops.totalCapacity == 2.8);
	auto print = uc.organizations.get("org-print");
	assert(print.headOfUnit == "" && print.totalMembers == 0, "former members do not count");
	assert(!uc.members.get("mem-lang").current && uc.members.get("mem-krueger").current);

	// enterprises: group structure, units, members and the derived managing director
	auto acme = uc.enterprises.get("ent-acme");
	assert(acme.totalUnits == 3 && acme.totalMembers == 5 && acme.managingDirector == "Dr. Klaus Brandt");
	auto acmeIt = uc.enterprises.get("ent-acme-it");
	assert(acmeIt.hierarchyPath == "ACME Group SE / ACME IT Services GmbH");
	assert(acmeIt.totalUnits == 3 && acmeIt.managingDirector == "Markus Weber");
	assert(acmeIt.totalMembers == (bergerActive ? 5 : 4));

	// rules
	bool failed;
	MemberDto m;
	m.name = "Second Head"; m.organizationId = "org-it"; m.memberFunction = "Head";
	try uc.members.create(m); catch (ValidationException e) failed = e.field == "memberFunction";
	assert(failed, "a unit has at most one current head");
	m.memberFunction = "Employee"; m.personnelNumber = "P-4001";
	failed = false;
	try uc.members.create(m); catch (ValidationException e) failed = e.field == "personnelNumber";
	assert(failed, "personnel numbers are unique");
	m.personnelNumber = "P-9999"; m.employmentType = "Contractor";
	failed = false;
	try uc.members.create(m); catch (ValidationException e) failed = e.field == "endDate";
	assert(failed, "contractors need an end date");
	m.endDate = "2030-12-31";
	assert(uc.members.create(m).current);
	EnterpriseDto e;
	e.name = "Orphan share"; e.ownershipShare = 30;
	failed = false;
	try uc.enterprises.create(e); catch (ValidationException x) failed = x.field == "ownershipShare";
	assert(failed);

	// referential integrity across the structure
	foreach (del; [() => uc.enterprises.remove("ent-acme-it"), () => uc.organizations.remove("org-it-ops"),
			() => uc.users.remove("usr-krueger")]) {
		failed = false;
		try del(); catch (ReferentialIntegrityException) failed = true;
		assert(failed);
	}

	// the organisation manager role maintains the structure; members are not exported to ArchiMate
	auto rights = uc.access.rightsFor(AccessSubjectDto("x", "", false));
	assert(uc.roles.get("role-org-manager").permissionIds.canFind("perm-edit-members"));
	auto xml = uc.archimate.exportModel();
	assert(xml.canFind(`identifier="id-ent-acme" xsi:type="BusinessActor"`) && !xml.canFind("id-mem-"));
	assert(xml.canFind(`xsi:type="Association" source="id-ent-acme-it" target="id-org-it"`), "top-level units belong to their enterprise");
}

/// Multi-tenancy, backup and restore (platform level).
unittest {
	import std.algorithm : canFind, map;
	import std.array : array;
	auto platform = EamContainer.inMemoryPlatform();
	auto sys = AccessSubjectDto("operator", "", true, true, "");
	auto tenantAdmin = AccessSubjectDto("eam.admin", "", false, false, "");
	bool denied(scope void delegate() fn) {
		try fn(); catch (AccessDeniedException) return true;
		return false;
	}

	// the default tenant always exists; new tenants are isolated repositories
	auto def = platform.tenantUseCases("default");
	def.seeder.seed();
	TenantCreateDto req;
	req.tenant.id = "beta"; req.tenant.name = "Beta Corp"; req.adminUserName = "beta.admin";
	auto beta = platform.createTenant(req, sys);
	assert(beta.elements == 6, "administrator user, role and 4 permissions"); // 1 user + 1 role + 4 permissions
	auto betaUc = platform.tenantUseCases("beta");
	assert(betaUc.applications.list.length == 0 && def.applications.list.length == 5);
	ApplicationDto a; a.name = "Beta App";
	betaUc.applications.create(a);
	assert(def.applications.list.length == 5, "tenants do not see each other's data");
	assert(betaUc.access.rightsFor(AccessSubjectDto("beta.admin", "", false)).administrator);

	// tenant resolution: zone mapping wins, entering another tenant needs a user there
	auto b = platform.getTenant("beta", sys);
	b.zoneId = "zone-beta";
	platform.updateTenant("beta", b, sys);
	assert(platform.resolveTenant(AccessSubjectDto("anyone", "", false, false, "zone-beta"), "default") == "beta");
	assert(platform.resolveTenant(AccessSubjectDto("beta.admin", "", false, false, ""), "beta") == "beta");
	assert(denied({ platform.resolveTenant(AccessSubjectDto("j.becker", "", false, false, ""), "beta"); }));
	assert(denied({ platform.resolveTenant(AccessSubjectDto("x", "", true, false, ""), "nope"); }));
	assert(platform.resolveTenant(AccessSubjectDto("j.becker", "", false, false, ""), "") == "default");
	assert(platform.tenantsFor(sys).map!(t => t.id).array == ["default", "beta"]);
	assert(platform.tenantsFor(AccessSubjectDto("j.becker", "", false, false, "")).map!(t => t.id).array == ["default"]);
	b.status = "Suspended";
	platform.updateTenant("beta", b, sys);
	assert(denied({ platform.resolveTenant(AccessSubjectDto("beta.admin", "", false, false, ""), "beta"); }));
	b.status = "Active";
	platform.updateTenant("beta", b, sys);

	// tenant administration needs a system administrator
	assert(denied({ platform.listTenants(tenantAdmin); }));
	bool failed;
	TenantCreateDto bad;
	bad.tenant.id = "../etc"; bad.tenant.name = "x";
	try platform.createTenant(bad, sys); catch (ValidationException e) failed = e.field == "id";
	assert(failed, "tenant ids are file names - no path traversal");

	// backup: tenant administrators (unrestricted rights) of the tenant; viewers may not
	assert(platform.canBackup("default", tenantAdmin) && !platform.canBackup("default", AccessSubjectDto("s.yilmaz", "", false)));
	assert(denied({ platform.createBackup("default", "", AccessSubjectDto("s.yilmaz", "", false)); }));
	auto backup = platform.createBackup("default", "before cleanup", tenantAdmin);
	assert(backup.kind == "Manual" && backup.elements > 150 && backup.checksum.length == 64);
	assert(platform.listBackups("default", tenantAdmin)[0].comment == "before cleanup");

	// damage the data, then check and restore
	def.workPackages.remove("wp-bi-migration");
	def.workPackages.remove("wp-bi-design");
	auto check = platform.restoreBackup("default", backup.id, true, tenantAdmin);
	assert(check.checkOnly && !check.restored && def.workPackages.list.length == 5, "a check changes nothing");
	auto res = platform.restoreBackup("default", backup.id, false, tenantAdmin);
	assert(res.restored && res.safetyBackupId.length);
	def = platform.tenantUseCases("default"); // rebuilt after the restore
	assert(def.workPackages.list.length == 7 && def.workPackages.get("wp-bi-design").name == "Target architecture & design");
	auto safety = platform.listBackups("default", sys).map!(x => x.kind).array;
	assert(safety.canFind("PreRestore") && safety.canFind("Manual"));

	// tampered and foreign backups
	auto file = platform.backupFile("default", backup.id, sys).dup;
	file[$ / 2] ^= 0xFF;
	failed = false;
	try platform.restoreUpload("default", file, true, false, sys); catch (ValidationException) failed = true;
	assert(failed, "damaged files are rejected");
	auto original = platform.backupFile("default", backup.id, sys);
	assert(denied({ platform.restoreUpload("beta", original, true, false, AccessSubjectDto("beta.admin", "", false)); }),
		"only system administrators restore a backup of another tenant");
	auto copy = platform.restoreUpload("beta", original, false, true, sys);
	assert(copy.restored && copy.warnings.canFind!(w => w.canFind("is restored into")));
	assert(platform.tenantUseCases("beta").applications.list.length == 5, "tenant copied from a backup");

	// scheduled backups keep the newest `retention` (3 in memory) per tenant; deleting a tenant keeps a final backup
	foreach (_; 0 .. 4) platform.runScheduledBackups();
	import core.thread : Thread;
	import core.time : msecs;
	assert(platform.listBackups("beta", sys).map!(x => x.kind).array.canFind("Scheduled"));
	platform.deleteTenant("beta", sys);
	assert(denied({ platform.resolveTenant(sys, "beta"); }));
	assert(denied({ platform.deleteTenant("default", AccessSubjectDto("eam.admin", "", true, false, "")); }));
	failed = false;
	try platform.deleteTenant("default", sys); catch (ValidationException) failed = true;
	assert(failed, "the default tenant cannot be deleted");
}

/// Creating a tenant is all or nothing; demo data and an administrator user can be combined.
unittest {
	import std.algorithm : canFind, map;
	auto platform = EamContainer.inMemoryPlatform();
	auto sys = AccessSubjectDto("operator", "", true, true, "");
	TenantCreateDto req;
	req.tenant.id = "gamma"; req.tenant.name = "Gamma AG"; req.seedDemoData = true; req.adminUserName = "g.admin";
	auto t = platform.createTenant(req, sys);
	assert(t.elements > 150);
	assert(platform.tenantUseCases("gamma").access.rightsFor(AccessSubjectDto("g.admin", "", false)).administrator);
	// existing user name: gets the administrator role instead of a second account
	req.tenant.id = "delta"; req.adminUserName = "j.becker";
	platform.createTenant(req, sys);
	assert(platform.tenantUseCases("delta").users.get("usr-becker").roleIds.canFind("role-tenant-admin"));
	// failure: invalid administrator name -> no tenant left behind
	req.tenant.id = "epsilon"; req.adminUserName = "has blank";
	bool failed;
	try platform.createTenant(req, sys); catch (ValidationException) failed = true;
	assert(failed && !platform.listTenants(sys).map!(x => x.id).canFind("epsilon"));
}

/// Processes (IT processes, steps, KPIs), security (protection requirements, risks, controls) and reporting.
unittest {
	import std.algorithm : canFind;
	import neko.eam.application.usecases.reporting : reportTables;
	import neko.eam.domain.types : todayIso;
	auto uc = EamContainer.inMemory().useCases;
	uc.seeder.seed();
	bool failed;

	// processes: steps, KPI evaluation and the worst KPI per process
	auto inc = uc.itProcesses.get("itp-incident");
	assert(inc.totalSteps == 4 && inc.kpiStatus == "AtRisk");
	assert(uc.itProcesses.get("itp-change").kpiStatus == "OffTrack" && uc.itProcesses.get("itp-problem").kpiStatus == "NoData");
	assert(uc.itProcesses.get("itp-major").hierarchyPath == "Incident Management / Major Incident Handling");
	auto mttr = uc.processKpis.get("kpi-inc-mttr");
	assert(mttr.kpiStatus == "AtRisk" && mttr.achievement == 76.2);
	ProcessStepDto step;
	step.name = "Duplicate"; step.processId = "itp-incident"; step.sequenceNo = 20;
	try uc.processSteps.create(step); catch (ValidationException e) failed = e.field == "sequenceNo";
	assert(failed, "sequence numbers are unique per process");

	// security: maximum principle, one assessment per object, risk scoring, control status
	auto s4 = uc.protectionRequirements.get("pr-s4");
	assert(s4.overallLevel == "VeryHigh" && s4.reviewOverdue == (todayIso() > "2026-06-01"));
	ProtectionRequirementDto again;
	again.name = "CRM again"; again.applicationId = "app-crm";
	failed = false;
	try uc.protectionRequirements.create(again); catch (ValidationException e) failed = e.field == "applicationId";
	assert(failed, "one protection requirement per object");
	auto oracle = uc.securityRisks.get("risk-oracle");
	assert(oracle.riskScore == 16 && oracle.riskLevel == "High" && oracle.residualLevel == "Medium");
	auto accepted = uc.securityRisks.get("risk-print");
	accepted.likelihood = 5; accepted.impact = 5;
	failed = false;
	try uc.securityRisks.update("risk-print", accepted); catch (ValidationException e) failed = e.field == "status";
	assert(failed, "critical risks cannot be accepted");
	assert(uc.securityControls.get("ctl-mfa").mitigatedRisks == 2);
	assert(uc.securityControls.get("ctl-patch").overdue == (todayIso() > "2026-09-30"));
	failed = false;
	try uc.securityControls.remove("ctl-mfa"); catch (ReferentialIntegrityException) failed = true;
	assert(failed, "controls used by risks cannot be deleted");

	// reporting: filter, order, group with sum, names instead of ids
	auto p = uc.reporting.run("rep-portfolio", "tester");
	assert(p.rows.length == 5 && p.rows[0][0] == "SAP S/4HANA Finance" && p.rows[0][5] == "Finance");
	assert(p.groups[0].value == "Invest" && p.groups[0].count == 3 && p.groups[0].sum == 1_230_000 && p.totalSum == 1_505_000);
	auto risks = uc.reporting.run("rep-risks");
	assert(risks.rows.length == 3 && risks.rows[0][0] == "R-001");
	assert(uc.reporting.runBook("rb-board").length == 3);
	assert(reportTables([p]).length == 2, "rows and group summary");
	ReportDto bad;
	bad.name = "Broken"; bad.entitySet = "Applications"; bad.columns = ["name", "colour"];
	failed = false;
	try uc.reports.create(bad); catch (ValidationException e) failed = e.field == "columns";
	assert(failed, "report definitions are checked when saved");

	// reports run with the rights of the caller
	auto viewer = uc.access.useCasesFor(AccessSubjectDto("s.yilmaz", "", false));
	assert(viewer.reporting.run("rep-portfolio").rows.length == 5);
	failed = false;
	try viewer.reporting.run("rep-users"); catch (AccessDeniedException) failed = true;
	assert(failed, "a report on Users needs read access to Users");
	assert(uc.reporting.run("rep-users").rows.length == 7);

	auto xml = uc.archimate.exportModel();
	assert(xml.canFind(`identifier="id-risk-oracle" xsi:type="Assessment"`) && xml.canFind(`identifier="id-itp-change" xsi:type="BusinessProcess"`));
}

/// Running comments (journal) on every element: rights, order, cascade on delete, part of the backup.
unittest {
	import std.algorithm : all, canFind, map;
	import std.array : array;
	auto uc = EamContainer.inMemory().useCases;
	uc.seeder.seed();
	auto legacy = uc.comments.list("Applications", "app-legacycrm");
	assert(legacy.length == 2 && legacy[0].createdBy == "a.krueger", "newest first");
	assert(uc.comments.count("SecurityRisks", "risk-oracle") == 1);

	// every set can be commented; the element must exist
	auto c = uc.comments.add("Products", "prd-k8s-131", "Upgrade to 1.32 planned for Q1.", "r.neumann");
	assert(c.createdBy == "r.neumann" && c.createdAt.length && uc.comments.list("Products", "prd-k8s-131")[0].text.canFind("1.32"));
	bool failed;
	try uc.comments.add("Products", "prd-missing", "x", "r.neumann"); catch (EntityNotFoundException) failed = true;
	assert(failed);
	failed = false;
	try uc.comments.add("Products", "prd-k8s-131", "   ", "r.neumann"); catch (ValidationException e) failed = e.field == "text";
	assert(failed, "empty comments are rejected");

	// rights: reading / writing needs read access to the element; deleting: author or delete permission
	auto viewer = uc.access.useCasesFor(AccessSubjectDto("s.yilmaz", "", false));
	auto mine = viewer.comments.add("Applications", "app-bi", "Reporting users confirmed the migration window.", "s.yilmaz");
	auto seen = viewer.comments.list("Applications", "app-legacycrm", "s.yilmaz");
	assert(seen.all!(x => !x.deletable), "viewers cannot delete other users' comments");
	failed = false;
	try viewer.comments.remove(legacy[0].id, "s.yilmaz"); catch (AccessDeniedException) failed = true;
	assert(failed);
	viewer.comments.remove(mine.id, "s.yilmaz"); // own comment
	auto member = uc.access.useCasesFor(AccessSubjectDto("a.krueger", "", false));
	failed = false;
	try member.comments.list("Applications", "app-legacycrm", "a.krueger"); catch (AccessDeniedException) failed = true;
	assert(failed, "no read access to the element - no access to its comments");
	assert(member.comments.list("WorkPackages", "wp-crm-load", "a.krueger")[0].deletable, "own comment");
	auto owner = uc.access.useCasesFor(AccessSubjectDto("j.becker", "", false)); // may delete applications
	assert(owner.comments.list("Applications", "app-legacycrm", "j.becker").all!(x => x.deletable));

	// deleting an element removes its comments
	uc.comments.add("Organizations", "org-print", "Closed - printing outsourced.", "m.weber");
	uc.members.remove("mem-lang");
	uc.organizations.remove("org-print");
	failed = false;
	try uc.comments.list("Organizations", "org-print"); catch (EntityNotFoundException) failed = true;
	assert(failed);
	OrganizationDto again;
	again.id = "org-print"; again.name = "Print Centre (new)";
	uc.organizations.create(again);
	assert(uc.comments.count("Organizations", "org-print") == 0, "the old journal was removed with the element");

	// comments are part of a tenant backup
	auto platform = EamContainer.inMemoryPlatform();
	auto sys = AccessSubjectDto("op", "", true, true, "");
	auto def = platform.tenantUseCases("default");
	def.seeder.seed();
	auto b = platform.createBackup("default", "", sys);
	assert(b.counts.canFind!(x => x.setName == "Comments" && x.count == 5));
	def.comments.add("Applications", "app-crm", "temporary", "x");
	platform.restoreBackup("default", b.id, false, sys);
	assert(platform.tenantUseCases("default").comments.count("Applications", "app-crm") == 0);
}

// local sign-in: passwords of the repository users, kept out of the element data
unittest {
	import std.algorithm : canFind;
	auto c = EamContainer.inMemory();
	auto uc = c.useCases;
	uc.seeder.seed();
	auto ac = uc.access;
	auto operator = AccessSubjectDto("operator", "", true, true, "");
	bool fails(E)(scope void delegate() fn) {
		try fn(); catch (E) return true;
		return false;
	}

	// nobody can sign in before a password was set; unknown users get the same error
	assert(!ac.hasPassword("m.weber"));
	assert(fails!InvalidCredentialsException({ ac.signIn("m.weber", "whatever 123"); }));
	assert(fails!InvalidCredentialsException({ ac.signIn("nobody", "whatever 123"); }));

	// only user administrators set passwords; the policy applies
	assert(fails!AccessDeniedException({ ac.setPassword("m.weber", "Archi tect 2026", AccessSubjectDto("s.yilmaz")); }));
	assert(fails!ValidationException({ ac.setPassword("m.weber", "short", operator); }));
	assert(fails!EntityNotFoundException({ ac.setPassword("nobody", "Archi tect 2026", operator); }));
	ac.setPassword("m.weber", "Archi tect 2026", AccessSubjectDto("eam.admin"));
	assert(ac.hasPassword("M.Weber"));

	// sign-in is case-insensitive on the user name, exact on the password; must change after an admin reset
	auto s = ac.signIn(" M.WEBER ", "Archi tect 2026");
	assert(s.subject.userName == "m.weber" && s.displayName == "Markus Weber" && s.mustChangePassword && !s.subject.administrator);
	assert(fails!InvalidCredentialsException({ ac.signIn("m.weber", "archi tect 2026"); }));

	// own change: current password checked, flag cleared
	assert(fails!ValidationException({ ac.changePassword("m.weber", "wrong", "New pass word 9"); }));
	assert(fails!ValidationException({ ac.changePassword("m.weber", "Archi tect 2026", "Archi tect 2026"); }));
	ac.changePassword("m.weber", "Archi tect 2026", "New pass word 9");
	assert(!ac.signIn("m.weber", "New pass word 9").mustChangePassword);
	assert(fails!InvalidCredentialsException({ ac.signIn("m.weber", "Archi tect 2026"); }));

	// disabled users cannot sign in even with the right password
	ac.setPassword("f.employee", "Gone but 4gotten", operator);
	assert(fails!InvalidCredentialsException({ ac.signIn("f.employee", "Gone but 4gotten"); }));

	// passwords never appear in the element data, the workbook export or the search
	foreach (sheet; uc.transfer.exportAll()) assert(sheet.name != "Credentials");
	foreach (u; uc.users.list) foreach (v; u.tupleof) static if (is(typeof(v) == string)) assert(!v.canFind("pbkdf2"));
	assert(c.storage.load("Credentials").length == 2, "stored in the tenant storage (part of backups)");

	// deleting a user removes the password; removing a password ends local sign-in
	ac.removePassword("m.weber", operator);
	assert(!ac.hasPassword("m.weber"));
	UserDto temp;
	temp.name = "Temporary";
	temp.userName = "t.emp";
	auto created = uc.users.create(temp);
	ac.setPassword("t.emp", "Temporary 2026", operator);
	assert(c.storage.load("Credentials").length == 2);
	uc.users.remove(created.id);
	assert(c.storage.load("Credentials").length == 1);
}
