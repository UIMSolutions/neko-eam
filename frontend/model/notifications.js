/**
 * View model of the notification popover (shell bar): turns the backend list (/api/v1/notifications) into the
 * texts of the two notification groups "Alerts" and "Activity". Pure functions - the texts come from `oTexts`:
 *
 *   text(key, args)        i18n text, null if the key does not exist
 *   typeLabel(set)         "Product" for "Products"
 *   fieldLabel(set, name)  label of a field (meta model)
 *   date(iso), timestamp(iso)
 */
sap.ui.define([], function () {
	"use strict";

	var MAX_FIELDS = 4;

	function initials(sName) {
		var aParts = String(sName || "?").replace(/@.*$/, "").split(/[\s._-]+/).filter(Boolean);
		return ((aParts[0] || "?").charAt(0) + (aParts.length > 1 ? aParts[aParts.length - 1].charAt(0) : "")).toUpperCase();
	}

	function alertItem(n, oTexts) {
		var sName = n.elementName || n.elementId;
		var sTitle = oTexts.text("notifAlert" + n.kind, [sName]) || (sName + ": " + n.text);
		var aDescription = [oTexts.typeLabel(n.elementSet)];
		if (n.date) { aDescription.push(oTexts.text("notifDue", [oTexts.date(n.date)])); }
		return {
			id: n.id, title: sTitle, description: aDescription.join(" · "), datetime: "", priority: n.priority,
			unread: n.unread, set: n.elementSet, elementId: n.elementId, navigable: true, authorInitials: ""
		};
	}

	function activityItem(n, oTexts) {
		var sName = n.elementName || n.elementId;
		var sType = oTexts.typeLabel(n.elementSet);
		var sTitle = oTexts.text("notifActivity" + n.kind, [n.actor, sType, sName]) || (n.actor + ": " + n.kind + " " + sName);
		var sDescription = "";
		if (n.kind === "Commented" && n.text) {
			sDescription = "“" + n.text + "”";
		} else if (n.kind === "Updated" && (n.fields || []).length) {
			var aLabels = n.fields.slice(0, MAX_FIELDS).map(function (f) { return oTexts.fieldLabel(n.elementSet, f); });
			if (n.fields.length > MAX_FIELDS) { aLabels.push(oTexts.text("notifMoreFields", [n.fields.length - MAX_FIELDS])); }
			sDescription = oTexts.text("notifChangedFields", [aLabels.join(", ")]);
		}
		return {
			id: n.id, title: sTitle, description: sDescription, datetime: oTexts.timestamp(n.date), priority: n.priority,
			unread: n.unread, set: n.elementSet, elementId: n.elementId, navigable: n.kind !== "Deleted",
			authorInitials: initials(n.actor)
		};
	}

	return {
		/** { unread, badge, alerts: [item], activities: [item] } */
		toViewModel: function (oList, oTexts) {
			var aItems = (oList && oList.items) || [];
			var iUnread = (oList && oList.unread) || 0;
			return {
				unread: iUnread,
				badge: this.badge(iUnread),
				alerts: aItems.filter(function (n) { return n.category === "alert"; }).map(function (n) { return alertItem(n, oTexts); }),
				activities: aItems.filter(function (n) { return n.category === "activity"; }).map(function (n) { return activityItem(n, oTexts); })
			};
		},

		/** Number shown on the bell: "" for none, "99+" for many. */
		badge: function (iUnread) {
			return iUnread > 0 ? (iUnread > 99 ? "99+" : String(iUnread)) : "";
		},

		initials: initials
	};
});
