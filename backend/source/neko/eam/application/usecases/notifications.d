/// Notifications (Fiori shell bar): alerts and activities, with a read / dismissed state per user.
///
/// * Alerts are computed from the data: product lifecycle alerts (severity Medium or higher), overdue
///   reviews of architecture documents and protection requirements, delayed work packages, overdue security
///   controls, open security risks past their due date and KPIs off track. Everybody who may read the set sees
///   them. They are computed once per change of the repository (and day), not per request.
/// * Activities are recorded from the domain events: changes, deletions and comments of one user are shown to
///   the users concerned - the element's creator, its last editor before the change and everybody who
///   commented on it (a user whose account was changed also sees that). Nobody sees own changes. Creating an
///   element concerns nobody yet.
///
/// The interactor is also the tenant's event listener (`IEventPublisher`) and is told about new comments.
module neko.eam.application.usecases.notifications;

import std.algorithm : canFind, filter, map, min, sort;
import std.array : array;
import std.conv : to;
import std.datetime : Clock;
import std.uuid : randomUUID;
import neko.eam.domain;
import neko.eam.application.dtos;
import neko.eam.ports.messaging;
import neko.eam.ports.repositories;
import neko.eam.ports.usecases;

class NotificationsInteractor : INotifications, IEventPublisher {
	/// Most activities shown to a user (newest first).
	enum maxActivities = 100;

	private {
		IEamUseCases _base;              // unrestricted use cases of the tenant
		IRepositoryRegistry _registry;   // change counters (alert cache)
		IActivityRepository _activities;
		INotificationStateRepository _states;
		ICommentRepository _comments;
		NotificationDto[] _alerts;
		ulong _alertStamp = ulong.max;
		string _alertDay;
	}

	this(IEamUseCases base, IRepositoryRegistry registry, IActivityRepository activities,
			INotificationStateRepository states, ICommentRepository comments) {
		_base = base; _registry = registry; _activities = activities; _states = states; _comments = comments;
	}

	// ---------------------------------------------------------------- INotifications

	NotificationListDto forUser(AccessSubjectDto subject) {
		auto me = userKey(subject.userName);
		auto state = _states.find(me);
		return build(subject, me, state is null ? null : state.read, state is null ? null : state.dismissed);
	}

	NotificationListDto markRead(AccessSubjectDto subject, string[] ids, bool all = false) {
		return change(subject, ids, all, false);
	}

	NotificationListDto dismiss(AccessSubjectDto subject, string[] ids, bool all = false) {
		return change(subject, ids, all, true);
	}

	// ---------------------------------------------------------------- recording

	/// Domain events of the tenant's use cases.
	void publish(DomainEvent e) {
		if (e.type != "Updated" && e.type != "Deleted") return;
		string[] audience = [e.createdBy, e.modifiedBy];
		foreach (c; _comments.forElement(e.kind, e.id)) audience ~= c.createdBy;
		if (e.kind == "Users" && e.type == "Updated") { // the user whose account (roles, validity) changed
			try audience ~= _base.users.get(e.id).userName;
			catch (Exception) {}
		}
		record(e.type, e.kind, e.id, e.name, e.actor, null, e.fields, audience);
	}

	/// A comment was added (unrestricted comment use cases).
	void commentAdded(Comment c) {
		string name, createdBy, modifiedBy;
		static foreach (S; EamDtoSets) {
			if (S.setName == c.elementSet) {
				try {
					auto dto = manage!S(_base).get(c.elementId);
					name = dto.name; createdBy = dto.createdBy; modifiedBy = dto.modifiedBy;
				} catch (Exception) {}
			}
		}
		string[] audience = [createdBy, modifiedBy];
		foreach (o; _comments.forElement(c.elementSet, c.elementId)) audience ~= o.createdBy;
		auto text = c.text.length > maxActivityTextLength ? c.text[0 .. maxActivityTextLength] ~ "…" : c.text;
		record("Commented", c.elementSet, c.elementId, name, c.createdBy, text, null, audience);
	}

	private void record(string type, string set, string id, string name, string actor, string text, string[] fields,
			string[] people) {
		auto self = userKey(actor);
		string[] audience;
		foreach (p; people) {
			auto k = userKey(p);
			if (k.length && k != self && !audience.canFind(k)) audience ~= k;
		}
		if (!audience.length) return; // nobody concerned
		auto a = new Activity;
		a.id = "act-" ~ randomUUID().toString()[0 .. 18];
		a.type = type;
		a.elementSet = set;
		a.elementId = id;
		a.elementName = name;
		a.actor = actor.length ? actor : "system";
		a.at = Clock.currTime().toUTC().toISOExtString();
		a.text = text;
		a.fields = fields;
		a.audience = audience;
		_activities.add(a);
	}

	// ---------------------------------------------------------------- internals

	private NotificationListDto change(AccessSubjectDto subject, string[] ids, bool all, bool dismissing) {
		auto me = userKey(subject.userName);
		if (!me.length) throw new ValidationException("user", "Notifications need a signed-in user");
		auto state = _states.find(me);
		if (state is null) { state = new NotificationState; state.user = me; }
		if (all) ids = build(subject, me, state.read, state.dismissed).items.map!(n => n.id).array;
		if (dismissing) state.dismissed ~= ids;
		else state.read ~= ids;
		// keep only ids that still exist: the state cannot grow without bound
		bool[string] known;
		foreach (n; alerts) known[n.id] = true;
		foreach (a; _activities.all) known[a.id] = true;
		state.read = unique(state.read.filter!(id => (id in known) !is null).array);
		state.dismissed = unique(state.dismissed.filter!(id => (id in known) !is null).array);
		_states.save(state);
		return build(subject, me, state.read, state.dismissed);
	}

	private NotificationListDto build(AccessSubjectDto subject, string me, string[] read, string[] dismissed) {
		bool[string] readable;
		foreach (s; _base.access.rightsFor(subject).sets) if (s.read) readable[s.setName] = true;
		bool[string] isRead, isDismissed;
		foreach (id; read) isRead[id] = true;
		foreach (id; dismissed) isDismissed[id] = true;

		NotificationListDto r;
		foreach (n; alerts) {
			if (n.elementSet !in readable || n.id in isDismissed) continue;
			n.unread = (n.id in isRead) is null;
			r.items ~= n;
		}
		if (me.length) {
			auto all = _activities.all;
			size_t shown;
			foreach_reverse (a; all) {
				if (shown >= maxActivities) break;
				if (!a.audience.canFind(me) || a.elementSet !in readable || a.id in isDismissed) continue;
				NotificationDto n = { id: a.id, category: "activity", kind: a.type,
					priority: a.type == "Deleted" ? "Medium" : "Low", elementSet: a.elementSet, elementId: a.elementId,
					elementName: a.elementName, date: a.at, actor: a.actor, text: a.text, fields: a.fields.dup,
					unread: (a.id in isRead) is null };
				r.items ~= n;
				shown++;
			}
		}
		foreach (n; r.items) if (n.unread) r.unread++;
		return r;
	}

	/// All alerts of the tenant (cached until the repository changes or the day changes).
	private NotificationDto[] alerts() {
		ulong stamp;
		foreach (repo; _registry.all) stamp += repo.changeCount;
		auto day = todayIso();
		if (stamp == _alertStamp && day == _alertDay) return _alerts;
		_alerts = computeAlerts(day);
		_alertStamp = stamp;
		_alertDay = day;
		return _alerts;
	}

	private NotificationDto[] computeAlerts(string today) {
		NotificationDto[] r;
		void add(string kind, string priority, string set, string id, string name, string date, string text) {
			NotificationDto n = { id: "alert:" ~ kind ~ ":" ~ set ~ ":" ~ id ~ ":" ~ date, category: "alert", kind: kind,
				priority: priority, elementSet: set, elementId: id, elementName: name, date: date, text: text, unread: true };
			r ~= n;
		}
		foreach (a; _base.analysis.productAlerts) {
			auto severity = a.severity.to!RiskLevel;
			if (severity < RiskLevel.Medium) continue;
			add("Product" ~ a.kind, severity >= RiskLevel.High ? "High" : "Medium", "Products", a.productId,
				a.productVersion.length ? a.productName ~ " " ~ a.productVersion : a.productName, a.date, a.message);
		}
		foreach (d; _base.architectureDocuments.list)
			if (d.reviewOverdue) add("DocumentReviewOverdue", "Medium", "ArchitectureDocuments", d.id, d.name, d.nextReviewDate, "Review overdue");
		foreach (p; _base.protectionRequirements.list)
			if (p.reviewOverdue) add("ProtectionReviewOverdue", "Medium", "ProtectionRequirements", p.id, p.name, p.nextReviewDate, "Review overdue");
		foreach (w; _base.workPackages.list)
			if (w.delayed) add("WorkPackageDelayed", "Medium", "WorkPackages", w.id, w.name, w.endDate, "Delayed");
		foreach (c; _base.securityControls.list)
			if (c.overdue) add("ControlOverdue", "High", "SecurityControls", c.id, c.name, c.dueDate, "Implementation overdue");
		foreach (k; _base.securityRisks.list) {
			if (k.status == "Closed" || k.status == "Accepted" || !k.dueDate.length || k.dueDate >= today) continue;
			auto high = k.riskLevel == "High" || k.riskLevel == "Critical";
			add("RiskDue", high ? "High" : "Medium", "SecurityRisks", k.id, k.name, k.dueDate, "Treatment overdue");
		}
		foreach (k; _base.processKpis.list)
			if (k.kpiStatus == "OffTrack") add("KpiOffTrack", "Medium", "ProcessKpis", k.id, k.name, k.measuredAt, "Off track");
		static int rank(string p) { return p == "High" ? 0 : p == "Medium" ? 1 : 2; }
		r.sort!((a, b) => rank(a.priority) < rank(b.priority)
			|| (rank(a.priority) == rank(b.priority) && (a.date < b.date || (a.date == b.date && a.id < b.id))));
		return r;
	}

	private static string[] unique(string[] ids) {
		bool[string] seen;
		string[] r;
		foreach (id; ids) if (id !in seen) { seen[id] = true; r ~= id; }
		return r;
	}
}

/// Forwards every event to several listeners (audit log, notifications).
class CompositeEventPublisher : IEventPublisher {
	private IEventPublisher[] _targets;

	this(IEventPublisher[] targets...) {
		foreach (t; targets) if (t !is null) _targets ~= t;
	}

	void publish(DomainEvent e) {
		foreach (t; _targets) t.publish(e);
	}
}
