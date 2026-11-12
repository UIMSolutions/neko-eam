/*global QUnit */
sap.ui.define([
	"uim/eam/model/formatter"
], function (formatter) {
	"use strict";

	QUnit.module("formatter");

	QUnit.test("lifecycle status state", function (assert) {
		assert.strictEqual(formatter.statusState("Active"), "Success");
		assert.strictEqual(formatter.statusState("PhaseOut"), "Warning");
		assert.strictEqual(formatter.statusState("Retired"), "Error");
		assert.strictEqual(formatter.statusState("Build"), "Information");
		assert.strictEqual(formatter.statusState(undefined), "None");
	});

	QUnit.test("TIME state", function (assert) {
		assert.strictEqual(formatter.timeState("Invest"), "Success");
		assert.strictEqual(formatter.timeState("Migrate"), "Warning");
		assert.strictEqual(formatter.timeState("Eliminate"), "Error");
	});

	QUnit.test("capability coverage", function (assert) {
		assert.strictEqual(formatter.coverageText(true, false), "Gap");
		assert.strictEqual(formatter.coverageText(false, true), "Redundant");
		assert.strictEqual(formatter.coverageState(false, false), "Success");
	});

	QUnit.test("helpers", function (assert) {
		assert.strictEqual(formatter.list(["a", "b"]), "a, b");
		assert.strictEqual(formatter.list(null), "");
		assert.strictEqual(formatter.count(["a"]), 1);
		assert.strictEqual(formatter.kiloAmount(1435000), "1,435k");
		assert.strictEqual(formatter.score("4"), 4);
		assert.strictEqual(formatter.millionAmount(1435000), "1.4");
	});

	QUnit.test("generic value state", function (assert) {
		assert.strictEqual(formatter.valueState("Approved"), "Success");
		assert.strictEqual(formatter.valueState("Requested"), "Information");
		assert.strictEqual(formatter.valueState("Deprecated"), "Warning");
		assert.strictEqual(formatter.valueState("Withdrawn"), "Error");
		assert.strictEqual(formatter.valueState("whatever"), "None");
		assert.strictEqual(formatter.severityState("Critical"), "Error");
		assert.strictEqual(formatter.severityHighlight("Medium"), "Information");
	});

	QUnit.test("references and display values", function (assert) {
		var mNames = { "p1": "Java", "p2": "HANA" };
		assert.strictEqual(formatter.refName("p1", mNames), "Java");
		assert.strictEqual(formatter.refName("unknown", mNames), "unknown");
		assert.strictEqual(formatter.refName("", mNames), "–");
		assert.strictEqual(formatter.refNames(["p1", "p2"], mNames), "Java, HANA");
		assert.strictEqual(formatter.text(""), "–");
		assert.strictEqual(formatter.text(0), "0");
		assert.strictEqual(formatter.yesNo(true), "Yes");
		assert.strictEqual(formatter.date(""), "–");
		assert.ok(formatter.date("2026-11-12").indexOf("2026") >= 0);
		assert.strictEqual(formatter.setCount({ Products: 6 }, "Products"), "6");
		assert.strictEqual(formatter.setCount({}, "Products"), "");
	});
});
