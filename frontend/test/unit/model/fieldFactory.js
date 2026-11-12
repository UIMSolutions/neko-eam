/*global QUnit */
sap.ui.define([
	"uim/eam/model/fieldFactory"
], function (fieldFactory) {
	"use strict";

	var oSet = { fields: [
		{ name: "name", type: "String", choices: [], defaultValue: "" },
		{ name: "lifecycleStatus", type: "String", choices: ["Plan", "Active"], defaultValue: "Active" },
		{ name: "isBlacklisted", type: "Boolean", choices: [], defaultValue: "false" },
		{ name: "licenseCosts", type: "Double", choices: [], defaultValue: "0" },
		{ name: "endOfLife", type: "Date", choices: [], defaultValue: "" },
		{ name: "usedProductIds", type: "StringCollection", choices: [], reference: "Products", defaultValue: "" },
		{ name: "modifiedAt", type: "String", choices: [], readOnly: true, defaultValue: "" }
	] };

	QUnit.module("fieldFactory");

	QUnit.test("defaults of a new element", function (assert) {
		assert.deepEqual(fieldFactory.defaults(oSet), {
			name: "", lifecycleStatus: "Active", isBlacklisted: false, licenseCosts: 0, endOfLife: "", usedProductIds: []
		});
	});

	QUnit.test("normalize converts edited values into OData JSON types", function (assert) {
		var o = fieldFactory.normalize(oSet, {
			name: "X", lifecycleStatus: "Plan", isBlacklisted: 1, licenseCosts: "12.5", endOfLife: "", usedProductIds: null, modifiedAt: "t"
		});
		assert.deepEqual(o, { name: "X", lifecycleStatus: "Plan", isBlacklisted: true, licenseCosts: 12.5, endOfLife: null, usedProductIds: [] });
	});

	QUnit.test("controls by field type", function (assert) {
		assert.ok(fieldFactory.createEditor(oSet.fields[1], "obj").isA("sap.m.Select"), "enumeration -> Select");
		assert.ok(fieldFactory.createEditor(oSet.fields[2], "obj").isA("sap.m.CheckBox"), "boolean -> CheckBox");
		assert.ok(fieldFactory.createEditor(oSet.fields[4], "obj").isA("sap.m.DatePicker"), "date -> DatePicker");
		assert.ok(fieldFactory.createEditor(oSet.fields[5], "obj").isA("sap.m.MultiComboBox"), "collection -> MultiComboBox");
		assert.ok(fieldFactory.createEditor(oSet.fields[6], "obj").isA("sap.m.Text"), "read-only -> Text");
		assert.ok(fieldFactory.createCell(oSet.fields[1]).isA("sap.m.ObjectStatus"), "enumeration cell -> ObjectStatus");
	});
});
