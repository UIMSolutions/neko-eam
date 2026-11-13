/*global QUnit */
sap.ui.define([
	"uim/eam/model/help"
], function (help) {
	"use strict";

	var mTexts = {
		helpTypeString: "Text", helpTypeInt32: "Whole number",
		helpTypeReference: "Reference to an element of {0}", helpTypeReferences: "References to elements of {0}",
		helpRequired: "Mandatory.", helpCalculated: "Calculated.", helpChoices: "Allowed values: {0}.", helpDefault: "Default: {0}.",
		helpAutomatic: "Recorded automatically.",
		helpField_timeCategory: "Gartner TIME.", helpField_Products_status: "Product status.",
		helpPage_list_title: "Working with the list", helpPage_list: "<p>list</p>",
		helpPage_overview_title: "Overview", helpPage_overview: "<p>overview</p>",
		helpSet_Applications: "<p>apps</p>", helpAboutSet: "About {0}", helpFieldsTitle: "Fields ({0})",
		helpTopicKeyboard_title: "Keyboard", helpTopicKeyboard: "<p>F1</p>"
	};
	function fnText(sKey, aArgs) {
		var s = mTexts[sKey];
		return s === undefined ? null : s.replace(/\{(\d)\}/g, function (m, i) { return aArgs[i]; });
	}
	function fnSetLabel(s) { return "[" + s + "]"; }

	QUnit.module("help");

	QUnit.test("field help: curated text plus what the meta model says", function (assert) {
		assert.strictEqual(help.fieldHelp({ name: "timeCategory", type: "String", choices: ["Tolerate", "Invest"], defaultValue: "" },
			"Applications", fnText, fnSetLabel), "Gartner TIME. Text. Allowed values: Tolerate, Invest.");
		assert.strictEqual(help.fieldHelp({ name: "status", type: "String", choices: [], defaultValue: "Active" }, "Products", fnText, fnSetLabel),
			"Product status. Text. Default: Active.", "set specific text wins");
		assert.strictEqual(help.fieldHelp({ name: "ownerOrganizationId", type: "String", choices: [], reference: "Organizations",
			required: true }, "Applications", fnText, fnSetLabel), "Reference to an element of [Organizations]. Mandatory.");
		assert.strictEqual(help.fieldHelp({ name: "totalUsers", type: "Int32", choices: [], readOnly: true, defaultValue: "0" },
			"Roles", fnText, fnSetLabel), "Whole number. Calculated.");
		assert.strictEqual(help.fieldHelp({ name: "modifiedBy", type: "String", choices: [], readOnly: true }, "Roles", fnText, fnSetLabel),
			"Recorded automatically.");
	});

	QUnit.test("page help of a list: the set, the page, general topics and the fields", function (assert) {
		var o = help.pageHelp("list", { set: "Applications" }, { name: "Applications", fields: [
			{ name: "id", label: "ID", type: "String", choices: [] },
			{ name: "timeCategory", label: "TIME Category", type: "String", choices: [] }
		] }, fnText, fnSetLabel);
		assert.strictEqual(o.title, "[Applications]");
		assert.deepEqual(o.sections.map(function (s) { return s.key; }), ["set", "list", "Keyboard"], "topics without text are skipped");
		assert.strictEqual(o.sections[0].title, "About [Applications]");
		assert.ok(o.sections[0].expanded && !o.sections[2].expanded);
		assert.deepEqual(o.fields.map(function (f) { return f.name; }), ["timeCategory"], "no help for the technical id");
		assert.strictEqual(o.fieldsTitle, "Fields (1)");
	});

	QUnit.test("unknown routes fall back to the overview, pages without a set have no fields", function (assert) {
		var o = help.pageHelp("unknown", {}, null, fnText, fnSetLabel);
		assert.strictEqual(o.title, "Overview");
		assert.strictEqual(o.fields.length, 0);
		assert.strictEqual(o.fieldsTitle, "");
	});
});
