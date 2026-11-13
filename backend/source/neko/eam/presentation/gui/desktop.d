/// Native GtkD desktop client working directly on the use cases (no HTTP).
module neko.eam.presentation.gui.desktop;

version (EamGui):

import neko.eam.domain.exceptions : AccessDeniedException;
import std.algorithm : canFind;
import std.array : join, replace;
import std.conv : to;
import std.format : format;
import std.file : write;

import gtk.Box;
import gtk.Button;
import gtk.CellRendererText;
import gtk.CheckButton;
import gtk.ComboBoxText;
import gtk.Dialog;
import gtk.Entry;
import gtk.FileChooserDialog;
import gtk.Grid;
import gtk.HeaderBar;
import gtk.Label : GtkLabel = Label;
import gtk.ListBox;
import gtk.ListBoxRow;
import gtk.SearchEntry;
import gtk.ListStore;
import gtk.Main;
import gtk.MainWindow;
import gtk.MenuButton;
import gtk.MessageDialog;
import gtk.Notebook;
import gtk.Popover;
import gtk.ScrolledWindow;
import gtk.Stack;
import gtk.StackSidebar;
import gtk.TextView;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;
import gtk.Window;
import gtkc.gobjecttypes : GType;
import gtkc.gtktypes;

import neko.eam.ports.usecases;
import neko.eam.infrastructure.security : localUserName;
import neko.eam.infrastructure.formats : codecFor, codecForContent;
import neko.eam.presentation.http.transfer : pickSheet;
static import std.file;

/// Starts the GTK main loop. Returns the exit code.
int runDesktopGui(string[] args, IEamPlatform platform) {
	Main.init(args);
	// EAM_TENANT=<id> selects the tenant, EAM_USER=<userName> acts as a repository user of it
	import std.process : environment;
	auto user = environment.get("EAM_USER", "");
	auto subject = user.length ? AccessSubjectDto(user, "", false, false, "") : AccessSubjectDto(localUserName(), "", true, true, "");
	auto uc = platform.tenantUseCases(platform.resolveTenant(subject, environment.get("EAM_TENANT", "")));
	auto app = new EamDesktopWindow(user.length ? uc.access.useCasesFor(AccessSubjectDto(user, "", false)) : uc,
		user.length ? user : localUserName());
	app.showAll();
	Main.run();
	return 0;
}

/// Table columns: id (row key) followed by the @ListColumn fields.
private FieldInfoDto[] listColumns(alias S)() {
	FieldInfoDto[] cols;
	foreach (f; describeFields!S()) if (f.name == "id" || f.listColumn) cols ~= f;
	return cols;
}

/// Callbacks of one sidebar page (one element set).
private struct SetPage {
	string setName;
	void delegate() refresh;
	void delegate() create;
	void delegate() edit;
	void delegate() remove;
	void delegate(string id) select;
	string delegate() selected;
}

/// Editor widget of one field in the edit dialog.
private struct FieldEditor {
	FieldInfoDto info;
	Entry entry;
	ComboBoxText combo;
	CheckButton check;

	string value() {
		if (check !is null) return check.getActive() ? "true" : "false";
		if (combo !is null) { auto id = combo.getActiveId(); return id is null ? "" : id; }
		return entry.getText();
	}
}

/// Sidebar order, aligned with the Fiori side navigation.
private enum sidebarOrder = ["Applications", "ApplicationGroups", "Products", "ProductGroups", "BusinessCapabilities",
	"BusinessProcesses", "BusinessData", "ServiceProductGroups", "StrategicGuidelines", "ServiceCapabilities", "MeasureGroups", "Measures",
	"ArchitecturePrinciples", "ArchitectureGuidelines", "ReferenceArchitectures", "ArchitectureDocuments",
	"Projects", "SubProjects", "WorkPackages", "ITComponents", "InformationFlows",
	"Enterprises", "Organizations", "Members", "ITProcesses", "ProcessSteps", "ProcessKpis",
	"ProtectionRequirements", "SecurityRisks", "SecurityControls", "Reports", "ReportBooks", "Users", "Roles", "Permissions"];

class EamDesktopWindow : MainWindow {
	private {
		IEamUseCases _uc;
		Stack _stack;
		SetPage[string] _pages;
		TextView _analysis;
		string _user;
	}

	this(IEamUseCases uc, string user) {
		super("Neko EAM");
		_uc = uc;
		_user = user;
		setDefaultSize(1360, 800);

		auto header = new HeaderBar();
		header.setTitle("Neko EAM");
		header.setSubtitle("Enterprise Architecture Management");
		header.setShowCloseButton(true);
		header.packStart(new Button("New", (Button b) => current(p => p.create())));
		header.packStart(new Button("Edit", (Button b) => current(p => p.edit())));
		header.packStart(new Button("Delete", (Button b) => current(p => p.remove())));
		header.packStart(new Button("Comments…", (Button b) => current(p => commentsDialog(p.setName, p.selected()))));
		header.packStart(new Button("Import…", (Button b) => importFile()));
		header.packStart(new Button("Export…", (Button b) => exportFile()));
		header.packEnd(userButton());
		header.packEnd(searchBox());
		header.packEnd(new Button("Export ArchiMate…", (Button b) => exportArchiMate()));
		header.packEnd(new Button("Refresh", (Button b) => refreshAll()));
		setTitlebar(header);

		_stack = new Stack();
		_stack.setTransitionType(StackTransitionType.CROSSFADE);
		_analysis = new TextView();
		_analysis.setEditable(false);
		_analysis.setMonospace(true);
		_analysis.setLeftMargin(12);
		_analysis.setTopMargin(12);
		_stack.addTitled(new ScrolledWindow(_analysis), "Analysis", "Overview & Analysis");
		foreach (name; sidebarOrder)
			static foreach (S; EamDtoSets) if (name == S.setName && canRead!S()) addSetPage!S();
		auto sidebar = new StackSidebar();
		sidebar.setStack(_stack);
		sidebar.setSizeRequest(220, -1);
		auto box = new Box(Orientation.HORIZONTAL, 0);
		box.packStart(sidebar, false, false, 0);
		box.packStart(_stack, true, true, 0);
		add(box);
		refreshAll();
	}

	private void current(void delegate(ref SetPage) action) {
		if (auto p = _stack.getVisibleChildName() in _pages) action(*p);
		else info("Select an element set in the sidebar first.");
	}

	/// Profile button (initials) with a popover showing the signed in user.
	private Widget userButton() {
		import std.ascii : toUpper;
		auto btn = new MenuButton();
		btn.setLabel(_user.length ? [cast(char) toUpper(_user[0])].idup ~ "  " ~ _user : "?");
		btn.setTooltipText("User profile");
		auto pop = new Popover(btn);
		auto vb = new Box(Orientation.VERTICAL, 6);
		vb.setBorderWidth(12);
		auto title = new GtkLabel("");
		title.setMarkup("<b>" ~ _user ~ "</b>");
		vb.packStart(title, false, false, 0);
		vb.packStart(new GtkLabel("Local desktop session – Architect (read & write)"), false, false, 0);
		vb.packStart(new GtkLabel("Changes are recorded as '" ~ _user ~ "@gui'"), false, false, 0);
		vb.showAll();
		pop.add(vb);
		btn.setPopover(pop);
		return btn;
	}

	/// Central search (same use case as the Fiori shell bar search): results in a popover,
	/// activating a hit opens the set page and selects the element.
	private Widget searchBox() {
		auto entry = new SearchEntry();
		entry.setPlaceholderText("Search all elements…");
		entry.setWidthChars(28);
		auto pop = new Popover(entry);
		pop.setModal(false);
		auto list = new ListBox();
		auto scroll = new ScrolledWindow(list);
		scroll.setSizeRequest(460, 360);
		pop.add(scroll);
		SearchHitDto[] hits;
		list.addOnRowActivated((ListBoxRow row, ListBox lb) {
			auto h = hits[row.getIndex()];
			pop.popdown();
			_stack.setVisibleChildName(h.setName);
			if (auto page = h.setName in _pages) page.select(h.id);
		});
		entry.addOnActivate((Entry e) {
			foreach (child; list.getChildren().toArray!Widget) list.remove(child);
			hits = _uc.search.search(e.getText(), 30);
			if (hits.length == 0) list.add(new GtkLabel("No elements found"));
			foreach (h; hits) {
				auto l = new GtkLabel("");
				l.setXalign(0);
				l.setMarkup(format("<b>%s</b>  <small>%s · %s</small>%s", escapeMarkup(h.name), escapeMarkup(h.typeLabel),
					escapeMarkup(h.id), h.matchedField.length
						? "\n<small><i>" ~ escapeMarkup(h.matchedField ~ ": " ~ h.snippet) ~ "</i></small>" : ""));
				l.setMarginStart(6);
				l.setMarginEnd(6);
				l.setMarginTop(4);
				l.setMarginBottom(4);
				list.add(l);
			}
			list.showAll();
			pop.popup();
		});
		return entry;
	}

	private static string escapeMarkup(string s) {
		import std.array : replace;
		return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
	}

	private void addSetPage(alias S)() {
		auto fields = listColumns!S();
		auto types = new GType[fields.length];
		types[] = GType.STRING;
		auto store = new ListStore(types);
		auto view = new TreeView(store);
		foreach (i, f; fields) {
			auto col = new TreeViewColumn(f.label, new CellRendererText(), "text", cast(int) i);
			col.setResizable(true);
			col.setSortColumnId(cast(int) i);
			view.appendColumn(col);
		}
		auto m = manage!S(_uc);

		string selectedId() {
			auto it = view.getSelectedIter();
			return it is null ? null : it.getValueString(0);
		}

		SetPage page;
		page.setName = S.setName;
		page.selected = () => selectedId();
		page.refresh = () {
			store.clear();
			foreach (dto; m.list) {
				auto values = toStringValues(dto);
				TreeIter it;
				store.append(it);
				foreach (i, f; fields) store.setValue(it, cast(int) i, values[f.name]);
			}
		};
		page.create = () {
			S.Dto blank;
			auto values = editDialog(S.label ~ " – new", describeFields!S(), toStringValues(blank), true);
			if (values is null) return;
			guarded(() {
				S.Dto dto;
				dto.applyStringValues(values);
				m.create(dto, _user ~ "@gui");
				refreshAll();
			});
		};
		page.edit = () {
			auto id = selectedId();
			if (id is null) return info("Select an element first.");
			guarded(() {
				auto dto = m.get(id);
				auto values = editDialog(S.label ~ " – " ~ dto.name, describeFields!S(), toStringValues(dto), false);
				if (values is null) return;
				dto.applyStringValues(values);
				m.update(id, dto, _user ~ "@gui");
				refreshAll();
			});
		};
		page.remove = () {
			auto id = selectedId();
			if (id is null) return info("Select an element first.");
			if (!confirm(format("Delete %s '%s'?", S.typeName, id))) return;
			guarded(() { m.remove(id, _user ~ "@gui"); refreshAll(); });
		};
		page.select = (string id) {
			TreeIter it;
			if (!store.getIterFirst(it)) return;
			do {
				if (it.getValueString(0) == id) {
					view.getSelection().selectIter(it);
					view.scrollToCell(store.getPath(it), null, false, 0, 0);
					return;
				}
			} while (store.iterNext(it));
		};
		view.addOnRowActivated((TreePath p, TreeViewColumn c, TreeView v) => page.edit());
		_pages[S.setName] = page;
		_stack.addTitled(new ScrolledWindow(view), S.setName, S.label);
	}

	/// Form with one tab per field group; enumerations and references are combo boxes,
	/// booleans check buttons, read-only values are shown but not editable. Returns null on cancel.
	private string[string] editDialog(string title, FieldInfoDto[] infos, string[string] values, bool isNew) {
		auto dialog = new Dialog(title, this, GtkDialogFlags.MODAL | GtkDialogFlags.DESTROY_WITH_PARENT,
			["Cancel", "Save"], [ResponseType.CANCEL, ResponseType.OK]);
		dialog.setDefaultSize(640, 560);
		auto tabs = new Notebook();
		tabs.setScrollable(true);
		Grid[string] grids;
		int[string] rows;
		FieldEditor[] editors;
		foreach (f; infos) {
			if (f.group !in grids) {
				auto g = new Grid();
				g.setRowSpacing(6);
				g.setColumnSpacing(12);
				g.setBorderWidth(12);
				grids[f.group] = g;
				rows[f.group] = 0;
				tabs.appendPage(new ScrolledWindow(g), new GtkLabel(f.group));
			}
			auto grid = grids[f.group];
			auto label = new GtkLabel(f.label ~ (f.required ? " *" : ""));
			label.setXalign(0);
			label.setTooltipText(f.name);
			FieldEditor ed;
			ed.info = f;
			Widget w;
			auto v = values.get(f.name, "");
			if (f.type == "Boolean") {
				ed.check = new CheckButton();
				ed.check.setActive(v == "true");
				w = ed.check;
			} else if (f.choices.length || (f.reference.length && f.type != "StringCollection")) {
				ed.combo = new ComboBoxText(false);
				if (f.reference.length) {
					ed.combo.append("", "–");
					foreach (opt; referenceOptions(f.reference)) ed.combo.append(opt[0], opt[1]);
				} else
					foreach (c; f.choices) ed.combo.append(c, c);
				ed.combo.setActiveId(v);
				w = ed.combo;
			} else {
				ed.entry = new Entry(v);
				if (f.type == "Date") ed.entry.setPlaceholderText("YYYY-MM-DD");
				if (f.type == "StringCollection") ed.entry.setPlaceholderText("ids, comma separated (" ~ f.reference ~ ")");
				if (f.name == "id" && isNew) ed.entry.setPlaceholderText("generated if empty");
				w = ed.entry;
			}
			w.setHexpand(true);
			if (f.readOnly || (f.name == "id" && !isNew)) w.setSensitive(false);
			grid.attach(label, 0, rows[f.group], 1, 1);
			grid.attach(w, 1, rows[f.group], 1, 1);
			rows[f.group]++;
			if (!f.readOnly && !(f.name == "id" && !isNew)) editors ~= ed;
		}
		dialog.getContentArea().packStart(tabs, true, true, 0);
		dialog.showAll();
		scope (exit) dialog.destroy();
		if (dialog.run() != ResponseType.OK) return null;
		string[string] result;
		foreach (ed; editors) result[ed.info.name] = ed.value();
		return result;
	}

	/// (id, "name (id)") pairs of the referenced set.
	private string[2][] referenceOptions(string setName) {
		string[2][] opts;
		static foreach (S; EamDtoSets)
			if (S.setName == setName)
				if (canRead!S()) foreach (d; manage!S(_uc).list) opts ~= [d.id, d.name ~ "  (" ~ d.id ~ ")"];
		return opts;
	}

	/// Sets without read permission get no sidebar page.
	private bool canRead(alias S)() {
		try { manage!S(_uc).count; return true; }
		catch (AccessDeniedException) return false;
	}

	private void refreshAll() {
		foreach (p; _pages.byValue) guarded(() => p.refresh());
		guarded(() => _analysis.getBuffer().setText(analysisText()));
	}

	private string analysisText() {
		PortfolioReportDto r;
		try r = _uc.analysis.portfolio();
		catch (AccessDeniedException e) return "Analysis not available: " ~ e.msg;
		string s = format("Portfolio report  (%s)\n\n", r.generatedAt);
		foreach (c; r.counts) s ~= format("  %-22s %4s\n", c.kind, c.count);
		s ~= format("\nOperational applications : %s (%s mission critical)\n", r.operationalApplications, r.missionCriticalApplications);
		s ~= format("Annual cost              : %.2f\n", r.totalAnnualCost);
		s ~= format("Capability gaps          : %s   redundancies: %s\n", r.capabilityGaps, r.capabilityRedundancies);
		s ~= "\nTIME assessment (BV/TF -> recommendation)\n";
		foreach (t; r.timeAssessments)
			s ~= format("  %-28s %d/%d  %-9s -> %-9s %s\n", t.applicationName, t.businessValue, t.technicalFit,
				t.current, t.recommended, t.deviates ? "(!)" : "");
		s ~= "\nTechnology risks\n";
		foreach (t; r.technologyRisks)
			s ~= format("  %-28s uses %-24s %s %s\n", t.applicationName, t.componentName, t.endOfSupportDate, t.reason);
		s ~= format("\nProduct lifecycle alerts (%s, %s critical)\n", r.productAlertCount, r.criticalProductAlerts);
		foreach (a; r.productAlerts)
			s ~= format("  %-8s %-20s %-18s %-10s %-11s %s  [%s]\n", a.severity, a.kind, a.productName, a.productVersion,
				a.date, a.message, a.applicationIds.join(", "));
		s ~= "\nCapability coverage\n";
		foreach (c; _uc.analysis.coverage())
			s ~= format("  %-34s L%d  %-10s %s\n", c.capabilityName, c.level,
				c.gap ? "GAP" : c.redundant ? "REDUNDANT" : "covered", c.supportingApplicationIds.join(", "));
		return s;
	}

	private void exportArchiMate() {
		auto chooser = new FileChooserDialog("Export ArchiMate model", this, FileChooserAction.SAVE,
			["Cancel", "Export"], [ResponseType.CANCEL, ResponseType.ACCEPT]);
		chooser.setCurrentName("eam-archimate.xml");
		chooser.setDoOverwriteConfirmation(true);
		scope (exit) chooser.destroy();
		if (chooser.run() == ResponseType.ACCEPT)
			guarded(() { write(chooser.getFilename(), _uc.archimate.exportModel()); info("Exported to " ~ chooser.getFilename()); });
	}

	/// Exports the visible set (CSV or XLSX by file extension); on the analysis page the whole repository as XLSX.
	private void exportFile() {
		auto set = _stack.getVisibleChildName() in _pages ? _stack.getVisibleChildName() : null;
		auto chooser = new FileChooserDialog(set ? "Export " ~ set : "Export repository", this, FileChooserAction.SAVE,
			["Cancel", "Export"], [ResponseType.CANCEL, ResponseType.ACCEPT]);
		chooser.setCurrentName("eam-" ~ (set ? set : "repository") ~ ".xlsx");
		chooser.setDoOverwriteConfirmation(true);
		addTableFilters(chooser);
		scope (exit) chooser.destroy();
		if (chooser.run() != ResponseType.ACCEPT) return;
		auto file = chooser.getFilename();
		guarded(() {
			auto codec = codecFor(file);
			auto sheets = set ? [_uc.transfer.exportSet(set)] : _uc.transfer.exportAll();
			write(file, codec.encode(sheets));
			info("Exported to " ~ file);
		});
	}

	/// Imports into the visible set, or every sheet of a workbook when the analysis page is shown.
	/// A dry run is shown first; the import runs only after confirmation.
	private void importFile() {
		auto set = _stack.getVisibleChildName() in _pages ? _stack.getVisibleChildName() : null;
		auto chooser = new FileChooserDialog(set ? "Import " ~ set : "Import repository (all sheets)", this,
			FileChooserAction.OPEN, ["Cancel", "Check"], [ResponseType.CANCEL, ResponseType.ACCEPT]);
		addTableFilters(chooser);
		scope (exit) chooser.destroy();
		if (chooser.run() != ResponseType.ACCEPT) return;
		auto file = chooser.getFilename();
		guarded(() {
			auto data = cast(const(ubyte)[]) std.file.read(file);
			auto sheets = codecForContent(data).decode(data);
			ImportResultDto[] run(bool dry) {
				return set ? [_uc.transfer.importSet(set, pickSheet(sheets, set), _user ~ "@gui", dry)]
					: _uc.transfer.importAll(sheets, _user ~ "@gui", dry);
			}
			auto preview = run(true);
			if (!confirm(importSummary(preview) ~ "\n\nImport now?")) return;
			auto results = run(false);
			refreshAll();
			info(importSummary(results));
		});
	}

	private static string importSummary(ImportResultDto[] results) {
		string s;
		size_t shown;
		foreach (r; results) {
			s ~= format("%s: %s created, %s updated, %s unchanged, %s failed\n", r.setName, r.created, r.updated, r.unchanged, r.failed);
			foreach (i; r.issues)
				if (shown++ < 15) s ~= format("   row %s %s%s: %s\n", i.row, i.severity, i.field.length ? " (" ~ i.field ~ ")" : "", i.message);
		}
		if (shown > 15) s ~= format("   … %s more issue(s)\n", shown - 15);
		return s;
	}

	private static void addTableFilters(FileChooserDialog chooser) {
		import gtk.FileFilter;
		foreach (pair; [["Excel workbook (*.xlsx)", "*.xlsx"], ["CSV (*.csv)", "*.csv"]]) {
			auto f = new FileFilter();
			f.setName(pair[0]);
			f.addPattern(pair[1]);
			chooser.addFilter(f);
		}
	}

	/// Running comments of the selected element: newest first, add a new one, delete own ones.
	private void commentsDialog(string setName, string id) {
		if (id is null) { info("Select an element first."); return; }
		auto dialog = new Dialog("Comments – " ~ setName ~ " " ~ id, this, GtkDialogFlags.MODAL | GtkDialogFlags.DESTROY_WITH_PARENT,
			["Close"], [GtkResponseType.CLOSE]);
		dialog.setDefaultSize(560, 460);
		auto history = new TextView();
		history.setEditable(false);
		history.setWrapMode(GtkWrapMode.WORD);
		history.setLeftMargin(8);
		void reload() {
			string text;
			foreach (c; _uc.comments.list(setName, id, _user))
				text ~= c.createdAt[0 .. c.createdAt.length >= 16 ? 16 : $].replace("T", " ") ~ "  " ~ c.createdBy ~ "\n" ~ c.text ~ "\n\n";
			history.getBuffer().setText(text.length ? text : "No comments yet.");
		}
		auto input = new TextView();
		input.setWrapMode(GtkWrapMode.WORD);
		input.setSizeRequest(-1, 70);
		auto add = new Button("Add comment", (Button b) {
			guarded(() {
				_uc.comments.add(setName, id, input.getBuffer().getText(), _user);
				input.getBuffer().setText("");
				reload();
			});
		});
		auto box = dialog.getContentArea();
		box.setSpacing(6);
		box.packStart(new ScrolledWindow(history), true, true, 0);
		box.packStart(new GtkLabel("New comment (date and author are recorded automatically):"), false, false, 0);
		box.packStart(input, false, false, 0);
		box.packStart(add, false, false, 0);
		guarded(() => reload());
		dialog.showAll();
		dialog.run();
		dialog.destroy();
	}

	private void guarded(void delegate() fn) {
		try fn();
		catch (Exception e) message(GtkMessageType.ERROR, e.msg);
	}

	private void info(string msg) { message(GtkMessageType.INFO, msg); }

	private void message(GtkMessageType type, string msg) {
		auto d = new MessageDialog(this, GtkDialogFlags.MODAL, type, GtkButtonsType.OK, "%s", msg);
		d.run();
		d.destroy();
	}

	private bool confirm(string msg) {
		auto d = new MessageDialog(this, GtkDialogFlags.MODAL, GtkMessageType.QUESTION, GtkButtonsType.YES_NO, "%s", msg);
		scope (exit) d.destroy();
		return d.run() == ResponseType.YES;
	}
}
