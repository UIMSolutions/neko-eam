/*global QUnit */
sap.ui.define([
	"uim/eam/model/notifications"
], function (notifications) {
	"use strict";

	var mTexts = {
		notifAlertProductEndOfLife: "End of life: {0}",
		notifDue: "Due {0}",
		notifActivityUpdated: "{0} changed {1} \"{2}\"",
		notifActivityCommented: "{0} commented on {1} \"{2}\"",
		notifChangedFields: "Changed: {0}",
		notifMoreFields: "+{0} more"
	};
	var oTexts = {
		text: function (sKey, aArgs) {
			var s = mTexts[sKey];
			return s === undefined ? null : s.replace(/\{(\d)\}/g, function (m, i) { return aArgs[i]; });
		},
		typeLabel: function (sSet) { return sSet.replace(/s$/, ""); },
		fieldLabel: function (sSet, sField) { return sField.toUpperCase(); },
		date: function (s) { return "d:" + s; },
		timestamp: function (s) { return "t:" + s; }
	};

	QUnit.module("notifications");

	QUnit.test("alerts and activities become the texts of the two groups", function (assert) {
		var o = notifications.toViewModel({ unread: 2, items: [
			{ id: "a1", category: "alert", kind: "ProductEndOfLife", priority: "High", elementSet: "Products", elementId: "p1",
				elementName: "Java 8", date: "2026-01-31", text: "End of life reached", unread: true },
			{ id: "a2", category: "alert", kind: "Unknown", priority: "Low", elementSet: "Products", elementId: "p2",
				elementName: "X", date: "", text: "Something", unread: false },
			{ id: "c1", category: "activity", kind: "Updated", priority: "Low", elementSet: "Applications", elementId: "app",
				elementName: "CRM", date: "2026-11-13T08:00:00Z", actor: "anna.berg", fields: ["a", "b", "c", "d", "e", "f"], unread: true },
			{ id: "c2", category: "activity", kind: "Deleted", priority: "Medium", elementSet: "Applications", elementId: "old",
				elementName: "Old", date: "2026-11-13T09:00:00Z", actor: "bob", unread: false }
		] }, oTexts);
		assert.strictEqual(o.badge, "2");
		assert.strictEqual(o.alerts.length, 2);
		assert.strictEqual(o.alerts[0].title, "End of life: Java 8");
		assert.strictEqual(o.alerts[0].description, "Product · Due d:2026-01-31");
		assert.strictEqual(o.alerts[1].title, "X: Something", "unknown kind: name and backend message");
		assert.strictEqual(o.activities[0].title, "anna.berg changed Application \"CRM\"");
		assert.strictEqual(o.activities[0].description, "Changed: A, B, C, D, +2 more");
		assert.strictEqual(o.activities[0].datetime, "t:2026-11-13T08:00:00Z");
		assert.strictEqual(o.activities[0].authorInitials, "AB");
		assert.notOk(o.activities[1].navigable, "a deleted element cannot be opened");
	});

	QUnit.test("badge", function (assert) {
		assert.strictEqual(notifications.badge(0), "");
		assert.strictEqual(notifications.badge(7), "7");
		assert.strictEqual(notifications.badge(250), "99+");
		assert.deepEqual(notifications.toViewModel(null, oTexts).alerts, []);
	});
});
