/**
 * Context help of the help panel (shell bar "?" / F1) and the help texts of the fields.
 *
 * Page help is assembled from i18n texts: the help of the current page (helpPage_<route>), for list and
 * object pages also the description of the entity set (helpSet_<Set>), followed by general topics. Field help
 * combines a curated text (helpField_<Set>_<field> or helpField_<field>) with what the meta model says about the
 * field (type, mandatory, allowed values, reference, calculated). Pure functions - texts come from `fnText(key,
 * args)`, which returns null for a missing key; `fnSetLabel(set)` gives the plural label of an entity set.
 */
sap.ui.define([], function () {
	"use strict";

	var ADMIN_FIELDS = ["createdAt", "createdBy", "modifiedAt", "modifiedBy"];
	var GENERAL_TOPICS = ["GettingStarted", "Navigation", "Search", "Notifications", "Rights", "Keyboard"];
	var ROUTES = ["overview", "list", "detail", "analysis", "backups", "tenants", "search", "report"];

	function typeText(oField, fnText, fnSetLabel) {
		if (oField.reference) {
			return fnText(oField.type === "StringCollection" ? "helpTypeReferences" : "helpTypeReference", [fnSetLabel(oField.reference)]);
		}
		return fnText("helpType" + oField.type) || oField.type;
	}

	return {
		/** Help text of a field of `sSet` (never empty). */
		fieldHelp: function (oField, sSet, fnText, fnSetLabel) {
			var aParts = [];
			var sCurated = fnText("helpField_" + sSet + "_" + oField.name) || fnText("helpField_" + oField.name);
			if (sCurated) { aParts.push(sCurated); }
			if (ADMIN_FIELDS.indexOf(oField.name) >= 0) {
				aParts.push(fnText("helpAutomatic"));
				return aParts.join(" ");
			}
			aParts.push(typeText(oField, fnText, fnSetLabel) + ".");
			if (oField.required) { aParts.push(fnText("helpRequired")); }
			if (oField.readOnly) { aParts.push(fnText("helpCalculated")); }
			if ((oField.choices || []).length) { aParts.push(fnText("helpChoices", [oField.choices.join(", ")])); }
			if (oField.defaultValue && oField.defaultValue !== "0" && oField.defaultValue !== "false") {
				aParts.push(fnText("helpDefault", [oField.defaultValue]));
			}
			return aParts.join(" ");
		},

		/**
		 * Help of the page of route `sRoute` (arguments `oArgs`); `oSetInfo` is the entity set of list / object
		 * pages (from the meta model, may be missing while it loads).
		 * Returns { title, sections: [{ key, title, html, expanded }], fields: [{ name, label, text }], fieldsTitle }.
		 */
		pageHelp: function (sRoute, oArgs, oSetInfo, fnText, fnSetLabel) {
			var sSet = oArgs && oArgs.set;
			var aSections = [];
			var sRouteKey = ROUTES.indexOf(sRoute) >= 0 ? sRoute : "overview";
			var sTitle = fnText("helpPage_" + sRouteKey + "_title") || fnText("helpTitle");
			if (sSet && (sRouteKey === "list" || sRouteKey === "detail")) {
				var sSetLabel = fnSetLabel(sSet);
				sTitle = sSetLabel;
				var sAbout = fnText("helpSet_" + sSet);
				if (sAbout) {
					aSections.push({ key: "set", title: fnText("helpAboutSet", [sSetLabel]), html: sAbout, expanded: true });
				}
			}
			aSections.push({ key: sRouteKey, title: fnText("helpPage_" + sRouteKey + "_title"), html: fnText("helpPage_" + sRouteKey),
				expanded: true });
			GENERAL_TOPICS.forEach(function (sTopic) {
				aSections.push({ key: sTopic, title: fnText("helpTopic" + sTopic + "_title"), html: fnText("helpTopic" + sTopic),
					expanded: false });
			});
			var aFields = [];
			if (oSetInfo && (sRouteKey === "list" || sRouteKey === "detail")) {
				aFields = oSetInfo.fields.filter(function (f) { return f.name !== "id"; }).map(function (f) {
					return { name: f.name, label: f.label, text: this.fieldHelp(f, oSetInfo.name, fnText, fnSetLabel) };
				}.bind(this));
			}
			return {
				title: sTitle,
				sections: aSections.filter(function (s) { return !!s.html; }),
				fields: aFields,
				fieldsTitle: aFields.length ? fnText("helpFieldsTitle", [aFields.length]) : ""
			};
		}
	};
});
