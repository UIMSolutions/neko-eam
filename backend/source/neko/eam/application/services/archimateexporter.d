/// ArchiMate 3.1 Open Exchange Format export of the architecture repository.
module neko.eam.application.services.archimateexporter;

import std.array : appender, Appender;
import std.format : formattedWrite;
import neko.eam.domain;
import neko.eam.ports.repositories;
import neko.eam.ports.services;

class ArchiMateExporter : IArchiMateExport {
	private {
		IElementRepository!Application _apps;
		IElementRepository!BusinessCapability _caps;
		IElementRepository!ITComponent _comps;
		IElementRepository!InformationFlow _flows;
		IElementRepository!Organization _orgs;
		IElementRepository!Project _projects;
		IElementRepository!Product _products;
		IElementRepository!ProductGroup _productGroups;
		IElementRepository!ApplicationGroup _appGroups;
		IElementRepository!BusinessProcess _processes;
		IElementRepository!BusinessData _data;
		IElementRepository!ServiceProductGroup _catalogs;
		IElementRepository!StrategicGuideline _guidelines;
		IElementRepository!ServiceCapability _serviceCaps;
		IElementRepository!MeasureGroup _measureGroups;
		IElementRepository!Measure _measures;
		IElementRepository!ArchitecturePrinciple _principles;
		IElementRepository!ArchitectureGuideline _archGuidelines;
		IElementRepository!ReferenceArchitecture _refArchs;
		IElementRepository!ArchitectureDocument _documents;
		IElementRepository!SubProject _subProjects;
		IElementRepository!WorkPackage _workPackages;
		IElementRepository!Enterprise _enterprises;
		IElementRepository!ITProcess _itProcesses;
		IElementRepository!ProcessStep _steps;
		IElementRepository!SecurityRisk _risks;
		IElementRepository!SecurityControl _controls;
	}

	this(IElementRepository!Application apps, IElementRepository!BusinessCapability caps,
		IElementRepository!ITComponent comps, IElementRepository!InformationFlow flows,
		IElementRepository!Organization orgs, IElementRepository!Project projects,
		IElementRepository!Product products, IElementRepository!ProductGroup productGroups,
		IElementRepository!ApplicationGroup appGroups, IElementRepository!BusinessProcess processes,
		IElementRepository!BusinessData data, IElementRepository!ServiceProductGroup catalogs,
		IElementRepository!StrategicGuideline guidelines, IElementRepository!ServiceCapability serviceCaps,
		IElementRepository!MeasureGroup measureGroups, IElementRepository!Measure measures,
		IElementRepository!ArchitecturePrinciple principles, IElementRepository!ArchitectureGuideline archGuidelines,
		IElementRepository!ReferenceArchitecture refArchs, IElementRepository!ArchitectureDocument documents,
		IElementRepository!SubProject subProjects, IElementRepository!WorkPackage workPackages,
		IElementRepository!Enterprise enterprises, IElementRepository!ITProcess itProcesses,
		IElementRepository!ProcessStep steps, IElementRepository!SecurityRisk risks, IElementRepository!SecurityControl controls) {
		_enterprises = enterprises;
		_itProcesses = itProcesses; _steps = steps; _risks = risks; _controls = controls;
		_subProjects = subProjects; _workPackages = workPackages;
		_principles = principles; _archGuidelines = archGuidelines; _refArchs = refArchs; _documents = documents;
		_processes = processes; _data = data; _catalogs = catalogs;
		_guidelines = guidelines; _serviceCaps = serviceCaps; _measureGroups = measureGroups; _measures = measures;
		_apps = apps; _caps = caps; _comps = comps; _flows = flows; _orgs = orgs; _projects = projects;
		_products = products; _productGroups = productGroups; _appGroups = appGroups;
	}

	string exportModel() {
		auto x = appender!string;
		x ~= `<?xml version="1.0" encoding="UTF-8"?>` ~ "\n";
		x ~= `<model xmlns="http://www.opengroup.org/xsd/archimate/3.0/" `
			~ `xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" identifier="id-eam-model">` ~ "\n";
		x ~= "  <name xml:lang=\"en\">Neko EAM Repository</name>\n  <elements>\n";
		foreach (e; _enterprises.findAll) element(x, e.id, "BusinessActor", e.name, e.description);
		foreach (p; _itProcesses.findAll) element(x, p.id, "BusinessProcess", p.name, p.purpose.length ? p.purpose : p.description);
		foreach (s; _steps.findAll) element(x, s.id, "BusinessProcess", s.name, s.description);
		foreach (r; _risks.findAll) element(x, r.id, "Assessment", r.name, r.threat.length ? r.threat : r.description);
		foreach (c; _controls.findAll) element(x, c.id, "Requirement", c.controlReference.length ? c.controlReference ~ " " ~ c.name : c.name, c.description);
		foreach (o; _orgs.findAll) element(x, o.id, "BusinessActor", o.name, o.description);
		foreach (c; _caps.findAll) element(x, c.id, "Capability", c.name, c.description);
		foreach (a; _apps.findAll) element(x, a.id, "ApplicationComponent", a.name, a.description);
		foreach (c; _comps.findAll)
			element(x, c.id, c.category == TechnologyCategory.Hardware ? "Device" : "SystemSoftware", c.name, c.description);
		foreach (p; _projects.findAll) element(x, p.id, "WorkPackage", p.name, p.description);
		foreach (p; _products.findAll)
			element(x, p.id, "SystemSoftware", p.productVersion.length ? p.name ~ " " ~ p.productVersion : p.name, p.description);
		foreach (g; _productGroups.findAll) element(x, g.id, "Grouping", g.name, g.description);
		foreach (g; _appGroups.findAll) element(x, g.id, "Grouping", g.name, g.description);
		foreach (p; _processes.findAll) element(x, p.id, "BusinessProcess", p.name, p.description);
		foreach (d; _data.findAll)
			element(x, d.id, "BusinessObject", d.dataVersion.length ? d.name ~ " " ~ d.dataVersion : d.name, d.description);
		foreach (g; _catalogs.findAll) element(x, g.id, "Grouping", g.name, g.description);
		// IT landscape planning (ArchiMate motivation and implementation & migration layers)
		foreach (g; _guidelines.findAll) element(x, g.id, "Principle", g.name, g.rationale.length ? g.rationale : g.description);
		foreach (c; _serviceCaps.findAll) element(x, c.id, "Capability", c.name, c.description);
		foreach (g; _measureGroups.findAll) element(x, g.id, "Grouping", g.name, g.description);
		foreach (m; _measures.findAll) element(x, m.id, "WorkPackage", m.name, m.description);
		// specifications (motivation layer, groupings and representations)
		foreach (p; _principles.findAll) element(x, p.id, "Principle", p.name, p.statement.length ? p.statement : p.description);
		foreach (g; _archGuidelines.findAll)
			element(x, g.id, g.obligation == ObligationLevel.Mandatory ? "Constraint" : "Requirement", g.name, g.description);
		foreach (r; _refArchs.findAll) element(x, r.id, "Grouping", r.name, r.scopeDescription.length ? r.scopeDescription : r.description);
		foreach (d; _documents.findAll) element(x, d.id, "Representation", d.name, d.description);
		foreach (s; _subProjects.findAll) element(x, s.id, "WorkPackage", s.name, s.description);
		foreach (w; _workPackages.findAll) element(x, w.id, "WorkPackage", w.name, w.description);
		x ~= "  </elements>\n  <relationships>\n";
		foreach (c; _caps.findAll)
			if (c.parentId.length) relation(x, "Composition", c.parentId, c.id, "");
		string[string] enterpriseOf;
		foreach (o; _orgs.findAll) enterpriseOf[o.id] = o.enterpriseId;
		foreach (o; _orgs.findAll) {
			if (o.parentId.length) relation(x, "Composition", o.parentId, o.id, "");
			// top-level units of a legal entity (no parent unit within the same enterprise)
			if (o.enterpriseId.length && enterpriseOf.get(o.parentId, "") != o.enterpriseId)
				relation(x, "Association", o.enterpriseId, o.id, "legal entity");
		}
		foreach (p; _itProcesses.findAll) {
			if (p.parentProcessId.length) relation(x, "Composition", p.parentProcessId, p.id, "");
			foreach (b; p.businessProcessIds) relation(x, "Serving", p.id, b, "");
		}
		foreach (s; _steps.findAll) {
			relation(x, "Composition", s.processId, s.id, "");
			foreach (a; s.applicationIds) relation(x, "Serving", a, s.id, "");
		}
		foreach (r; _risks.findAll) {
			foreach (c; r.controlIds) relation(x, "Association", c, r.id, "mitigates");
			foreach (a; r.applicationIds) relation(x, "Association", r.id, a, "affects");
			foreach (t; r.componentIds) relation(x, "Association", r.id, t, "affects");
		}
		foreach (c; _controls.findAll) {
			foreach (a; c.applicationIds) relation(x, "Association", c.id, a, "applies to");
			foreach (t; c.componentIds) relation(x, "Association", c.id, t, "applies to");
		}
		// members are persons (personal data) and are deliberately not exported
		foreach (e; _enterprises.findAll)
			if (e.parentEnterpriseId.length) relation(x, "Aggregation", e.parentEnterpriseId, e.id, "subsidiary");
		foreach (a; _apps.findAll) {
			foreach (cid; a.capabilityIds) relation(x, "Realization", a.id, cid, "");
			foreach (tid; a.componentIds) relation(x, "Serving", tid, a.id, "");
			if (a.ownerOrganizationId.length) relation(x, "Association", a.ownerOrganizationId, a.id, "owns");
			foreach (pid; a.usedProductIds) relation(x, "Serving", pid, a.id, "used by");
			foreach (pid; a.assignedProductIds) relation(x, "Association", pid, a.id, "assigned");
			if (a.applicationGroupId.length) relation(x, "Aggregation", a.applicationGroupId, a.id, "");
		}
		foreach (p; _products.findAll) {
			if (p.productGroupId.length) relation(x, "Aggregation", p.productGroupId, p.id, "");
			if (p.componentId.length) relation(x, "Association", p.id, p.componentId, "version of");
		}
		foreach (g; _productGroups.findAll) {
			if (g.parentGroupId.length) relation(x, "Aggregation", g.parentGroupId, g.id, "");
			if (g.capabilityId.length) relation(x, "Association", g.id, g.capabilityId, "IT capability");
		}
		foreach (g; _appGroups.findAll) {
			if (g.parentGroupId.length) relation(x, "Aggregation", g.parentGroupId, g.id, "");
			if (g.capabilityId.length) relation(x, "Association", g.id, g.capabilityId, "IT capability");
		}
		foreach (p; _processes.findAll)
			if (p.parentProcessId.length) relation(x, "Composition", p.parentProcessId, p.id, "");
		foreach (d; _data.findAll) {
			if (d.capabilityId.length) relation(x, "Association", d.capabilityId, d.id, "uses");
			if (d.ownerOrganizationId.length) relation(x, "Association", d.ownerOrganizationId, d.id, "owns");
		}
		foreach (g; _catalogs.findAll)
			if (g.parentId.length) relation(x, "Aggregation", g.parentId, g.id, "");
		foreach (g; _guidelines.findAll) {
			if (g.parentId.length) relation(x, "Aggregation", g.parentId, g.id, "");
			foreach (cid; g.capabilityIds) relation(x, "Association", g.id, cid, "applies to");
		}
		foreach (c; _serviceCaps.findAll) {
			if (c.parentId.length) relation(x, "Composition", c.parentId, c.id, "");
			if (c.businessCapabilityId.length) relation(x, "Serving", c.id, c.businessCapabilityId, "");
			foreach (aid; c.applicationIds) relation(x, "Realization", aid, c.id, "");
			foreach (gid; c.serviceProductGroupIds) relation(x, "Association", c.id, gid, "catalogue");
		}
		foreach (g; _measureGroups.findAll) {
			if (g.parentGroupId.length) relation(x, "Aggregation", g.parentGroupId, g.id, "");
			foreach (sid; g.strategicGuidelineIds) relation(x, "Association", g.id, sid, "implements");
		}
		foreach (m; _measures.findAll) {
			if (m.measureGroupId.length) relation(x, "Aggregation", m.measureGroupId, m.id, "");
			if (m.projectId.length) relation(x, "Aggregation", m.projectId, m.id, "implements");
			foreach (sid; m.strategicGuidelineIds) relation(x, "Association", m.id, sid, "implements");
			foreach (cid; m.serviceCapabilityIds) relation(x, "Association", m.id, cid, "improves");
			foreach (aid; m.affectedApplicationIds) relation(x, "Association", m.id, aid, "changes");
			foreach (tid; m.affectedComponentIds) relation(x, "Association", m.id, tid, "changes");
		}
		foreach (p; _principles.findAll)
			foreach (sid; p.strategicGuidelineIds) relation(x, "Association", p.id, sid, "derived from");
		foreach (g; _archGuidelines.findAll) {
			foreach (pid; g.principleIds) relation(x, "Association", g.id, pid, "derived from");
			foreach (pid; g.standardProductIds) relation(x, "Association", g.id, pid, "standard");
			foreach (cid; g.componentIds) relation(x, "Association", g.id, cid, "applies to");
		}
		foreach (r; _refArchs.findAll) {
			if (r.parentId.length) relation(x, "Aggregation", r.parentId, r.id, "");
			foreach (id; r.principleIds) relation(x, "Association", r.id, id, "follows");
			foreach (id; r.guidelineIds) relation(x, "Association", r.id, id, "follows");
			foreach (id; r.capabilityIds) relation(x, "Association", r.id, id, "supports");
			foreach (id; r.componentIds) relation(x, "Aggregation", r.id, id, "");
			foreach (id; r.standardProductIds) relation(x, "Aggregation", r.id, id, "");
			foreach (id; r.applicationIds) relation(x, "Association", id, r.id, "implements");
		}
		foreach (d; _documents.findAll) {
			foreach (id; d.referenceArchitectureIds) relation(x, "Association", d.id, id, "describes");
			foreach (id; d.principleIds) relation(x, "Association", d.id, id, "describes");
			foreach (id; d.guidelineIds) relation(x, "Association", d.id, id, "describes");
			foreach (id; d.applicationIds) relation(x, "Association", d.id, id, "describes");
		}
		foreach (s; _subProjects.findAll) {
			relation(x, "Composition", s.parentSubProjectId.length ? s.parentSubProjectId : s.projectId, s.id, "");
			foreach (aid; s.affectedApplicationIds) relation(x, "Association", s.id, aid, "changes");
		}
		foreach (w; _workPackages.findAll) {
			relation(x, "Composition", w.subProjectId.length ? w.subProjectId : w.projectId, w.id, "");
			foreach (pid; w.predecessorIds) relation(x, "Triggering", pid, w.id, "");
			foreach (mid; w.measureIds) relation(x, "Association", w.id, mid, "implements");
			foreach (aid; w.affectedApplicationIds) relation(x, "Association", w.id, aid, "changes");
		}
		foreach (f; _flows.findAll) relation(x, "Flow", f.sourceApplicationId, f.targetApplicationId, f.dataObject.length ? f.dataObject : f.name);
		foreach (p; _projects.findAll)
			foreach (aid; p.affectedApplicationIds) relation(x, "Association", p.id, aid, "changes");
		x ~= "  </relationships>\n</model>\n";
		return x.data;
	}

	private size_t _relCounter;

	private static void element(ref Appender!string x, string id, string type, string name, string doc) {
		x.formattedWrite("    <element identifier=\"%s\" xsi:type=\"%s\">\n      <name xml:lang=\"en\">%s</name>\n",
			xmlId(id), type, xmlEscape(name));
		if (doc.length) x.formattedWrite("      <documentation xml:lang=\"en\">%s</documentation>\n", xmlEscape(doc));
		x ~= "    </element>\n";
	}

	private void relation(ref Appender!string x, string type, string source, string target, string name) {
		x.formattedWrite("    <relationship identifier=\"id-rel-%s\" xsi:type=\"%s\" source=\"%s\" target=\"%s\"",
			++_relCounter, type, xmlId(source), xmlId(target));
		if (name.length) x.formattedWrite(">\n      <name xml:lang=\"en\">%s</name>\n    </relationship>\n", xmlEscape(name));
		else x ~= "/>\n";
	}
}

/// ArchiMate identifiers are xs:ID values (NCName) - prefix and sanitise.
string xmlId(string id) pure @safe {
	import std.ascii : isAlphaNum;
	string r = "id-";
	foreach (char c; id) r ~= (isAlphaNum(c) || c == '-' || c == '_' || c == '.') ? c : '_';
	return r;
}

string xmlEscape(string s) pure @safe {
	string r;
	foreach (char c; s) switch (c) {
		case '&': r ~= "&amp;"; break;
		case '<': r ~= "&lt;"; break;
		case '>': r ~= "&gt;"; break;
		case '"': r ~= "&quot;"; break;
		case '\'': r ~= "&apos;"; break;
		default: r ~= c;
	}
	return r;
}

unittest {
	assert(xmlId("app 1") == "id-app_1");
	assert(xmlEscape("a<b&c") == "a&lt;b&amp;c");
}
