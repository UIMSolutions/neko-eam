/// Server-side rendered EAM cockpit (Diet templates + daisyUI) - works without JavaScript frameworks.
module neko.eam.presentation.web;

import neko.eam.presentation.http.access : callerUseCases;
import neko.eam.domain.exceptions : AccessDeniedException;
import std.array : join;
import std.conv : to;
import vibe.http.router : URLRouter;
import vibe.http.server;
import neko.eam.ports.usecases;

/// Table model handed to the Diet templates.
struct WebTable {
	string setName;
	string title;
	string[] headers;
	string[][] rows;
}

struct NavItem {
	string setName;
	string title;
	size_t count;
}

class WebCockpit {
	private IEamUseCases _uc;

	this(IEamUseCases uc) { _uc = uc; }

	void register(URLRouter router) {
		router.get("/web", &dashboard);
		router.get("/web/", &dashboard);
		router.get("/web/sets/:set", &setPage);
	}

	void dashboard(HTTPServerRequest req, HTTPServerResponse res) {
		auto uc = callerUseCases(_uc);
		typeof(uc.analysis.portfolio()) report;
		typeof(uc.analysis.coverage()) coverage;
		try { report = uc.analysis.portfolio(); coverage = uc.analysis.coverage(); }
		catch (AccessDeniedException) {} // the dashboard stays empty without read access to applications
		auto nav = navigation();
		string title = "Dashboard";
		res.render!("dashboard.dt", title, nav, report, coverage);
	}

	void setPage(HTTPServerRequest req, HTTPServerResponse res) {
		auto set = req.params["set"];
		auto nav = navigation();
		static foreach (S; EamDtoSets) {
			if (set == S.setName) {
				auto table = buildTable!S();
				string title = S.label;
				res.render!("elements.dt", title, nav, table);
				return;
			}
		}
		throw new HTTPStatusException(HTTPStatus.notFound, "Unknown element set");
	}

	private NavItem[] navigation() {
		NavItem[] items;
		auto uc = callerUseCases(_uc);
		static foreach (S; EamDtoSets) {
			try items ~= NavItem(S.setName, S.label, manage!S(uc).count);
			catch (AccessDeniedException) {} // only readable sets are offered
		}
		return items;
	}

	private WebTable buildTable(alias S)() {
		WebTable t;
		t.setName = S.setName;
		t.title = S.label;
		// id + list columns keep wide sets (e.g. Products with ~80 fields) readable
		string[] names;
		foreach (f; describeFields!S())
			if (f.name == "id" || f.listColumn) { names ~= f.name; t.headers ~= f.label; }
		S.Dto[] items;
		try items = manage!S(callerUseCases(_uc)).list;
		catch (AccessDeniedException e) throw new HTTPStatusException(HTTPStatus.forbidden, e.msg);
		foreach (dto; items) {
			auto values = toStringValues(dto);
			string[] row;
			foreach (n; names) row ~= values[n];
			t.rows ~= row;
		}
		return t;
	}
}
