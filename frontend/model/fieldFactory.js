/**
 * Builds UI5 controls from the backend meta model (/api/v1/model): form editors for the object page
 * and cells for list tables. Field types: String, Int32, Double, Boolean, Date, StringCollection;
 * `choices` (enumerations) and `reference` (entity set) refine the String types.
 */
sap.ui.define([
	"sap/m/Input",
	"sap/m/TextArea",
	"sap/m/Text",
	"sap/m/Select",
	"sap/m/ComboBox",
	"sap/m/MultiComboBox",
	"sap/m/CheckBox",
	"sap/m/DatePicker",
	"sap/m/ObjectStatus",
	"sap/m/ObjectNumber",
	"sap/m/ObjectIdentifier",
	"sap/m/Link",
	"sap/ui/core/Item",
	"sap/ui/core/ListItem",
	"sap/ui/core/CustomData",
	"uim/eam/model/formatter"
], function (Input, TextArea, Text, Select, ComboBox, MultiComboBox, CheckBox, DatePicker, ObjectStatus, ObjectNumber,
	ObjectIdentifier, Link, Item, ListItem, CustomData, formatter) {
	"use strict";

	var EDITABLE = "{= ${ui>/editable} && !${ui>/readOnly} }";

	function itemsFor(oField) {
		return oField.choices.map(function (sChoice) { return new Item({ key: sChoice, text: sChoice }); });
	}

	return {
		/** Editor for the object page; `sModel` is the JSON model holding the element (e.g. "obj"). */
		createEditor: function (oField, sModel) {
			var sPath = sModel + ">/" + oField.name;
			var bFixed = oField.readOnly;
			var oControl;
			if (oField.name === "id") {
				return new Input({ value: "{" + sPath + "}", editable: "{= ${ui>/isNew} }", placeholder: "{i18n>idPlaceholder}" });
			}
			if (bFixed) {
				var sText = oField.name === "createdAt" || oField.name === "modifiedAt"
					? { path: sPath, formatter: formatter.timestamp } : "{" + sPath + "}";
				return new Text({ text: sText });
			}
			if (oField.type === "Boolean") {
				oControl = new CheckBox({ selected: "{" + sPath + "}", editable: EDITABLE });
			} else if (oField.type === "Date") {
				oControl = new DatePicker({ value: "{" + sPath + "}", valueFormat: "yyyy-MM-dd", displayFormat: "medium", editable: EDITABLE });
			} else if (oField.type === "StringCollection") {
				oControl = new MultiComboBox({
					selectedKeys: "{" + sPath + "}",
					editable: EDITABLE,
					showSecondaryValues: true,
					items: { path: "lookup>/" + oField.reference + "List", templateShareable: false,
						template: new ListItem({ key: "{lookup>id}", text: "{lookup>name}", additionalText: "{lookup>id}" }) }
				});
			} else if (oField.reference) {
				oControl = new ComboBox({
					selectedKey: "{" + sPath + "}",
					editable: EDITABLE,
					showSecondaryValues: true,
					showClearIcon: true,
					items: { path: "lookup>/" + oField.reference + "List", templateShareable: false,
						template: new ListItem({ key: "{lookup>id}", text: "{lookup>name}", additionalText: "{lookup>id}" }) }
				});
			} else if (oField.choices.length) {
				oControl = new Select({ selectedKey: "{" + sPath + "}", editable: EDITABLE, forceSelection: false, items: itemsFor(oField), width: "100%" });
			} else if (oField.multiline) {
				oControl = new TextArea({ value: "{" + sPath + "}", editable: EDITABLE, rows: 3, growing: true, growingMaxLines: 10, width: "100%" });
			} else if (oField.type === "Int32" || oField.type === "Double") {
				oControl = new Input({ value: "{" + sPath + "}", type: "Number", editable: EDITABLE });
			} else {
				oControl = new Input({ value: "{" + sPath + "}", editable: EDITABLE });
			}
			oControl.data("field", oField.name);
			return oControl;
		},

		/**
		 * Display control (shown while not editing): references become links to the referenced element,
		 * enumerations status texts, dates and timestamps are formatted. `fnNavigate(set, id)` opens an element.
		 */
		createDisplay: function (oField, sModel, fnNavigate) {
			var sPath = sModel + ">/" + oField.name;
			if (oField.name === "createdAt" || oField.name === "modifiedAt") {
				return new Text({ text: { path: sPath, formatter: formatter.timestamp } });
			}
			if (oField.type === "Boolean") {
				return new Text({ text: { path: sPath, formatter: formatter.yesNo } });
			}
			if (oField.type === "Date") {
				return new Text({ text: { path: sPath, formatter: formatter.date } });
			}
			if (oField.type === "StringCollection" && oField.reference) {
				return new Text({ text: { parts: [sPath, "lookup>/" + oField.reference], formatter: formatter.refNames } });
			}
			if (oField.type === "StringCollection") {
				return new Text({ text: { path: sPath, formatter: formatter.list } });
			}
			if (oField.reference) {
				return new Link({
					text: { parts: [sPath, "lookup>/" + oField.reference], formatter: formatter.refName },
					press: function (oEvent) {
						var sId = oEvent.getSource().getModel(sModel).getProperty("/" + oField.name);
						if (sId) { fnNavigate(oField.reference, sId); }
					}
				});
			}
			if (oField.choices.length) {
				return new ObjectStatus({ text: "{" + sPath + "}", state: { path: sPath, formatter: formatter.valueState } });
			}
			if (/link$/i.test(oField.name)) {
				return new Link({ text: "{" + sPath + "}", href: "{" + sPath + "}", target: "_blank", wrapping: true });
			}
			return new Text({ text: { path: sPath, formatter: formatter.text }, renderWhitespace: !!oField.multiline });
		},

		/** Fills the collection cells (see createCell) of the rendered rows: names via the lookup model. */
		fillCollectionCells: function (oTable, oLookup) {
			oTable.getItems().forEach(function (oItem) {
				var oContext = oItem.getBindingContext();
				var oRow = oContext && oContext.getObject();
				if (!oRow) { return; }
				oItem.getCells().forEach(function (oCell) {
					var sPath = oCell.data && oCell.data("collection");
					if (!sPath) { return; }
					var sRef = oCell.data("reference");
					var aValues = oRow[sPath] || [];
					oCell.setText(sRef ? formatter.refNames(aValues, oLookup.getProperty("/" + sRef)) : formatter.list(aValues));
				});
			});
		},

		/** Cell of a list table bound against the OData V4 list binding. */
		createCell: function (oField) {
			var p = oField.name;
			if (p === "name") {
				return new ObjectIdentifier({ title: "{name}", text: "{id}" });
			}
			if (oField.type === "Boolean") {
				// raw value: the OData V4 Edm.Boolean type would otherwise hand the formatter a text ("No" is truthy)
				return new ObjectStatus({
					text: { path: p, targetType: "any", formatter: formatter.yesNo },
					state: { path: p, targetType: "any", formatter: function (b) { return b === true ? "Warning" : "None"; } }
				});
			}
			if (oField.choices.length) {
				return new ObjectStatus({ text: "{" + p + "}", state: { path: p, formatter: formatter.valueState } });
			}
			if (oField.type === "StringCollection") {
				// the OData V4 model does not hand collection values to a property binding - the text is filled
				// from the row data by fillCollectionCells (list "updateFinished")
				return new Text({ customData: [new CustomData({ key: "collection", value: p }),
					new CustomData({ key: "reference", value: oField.reference || "" })] });
			}
			if (oField.reference) {
				return new Text({ text: { parts: [{ path: p, targetType: "any" }, { path: "lookup>/" + oField.reference }],
					formatter: formatter.refName } });
			}
			if (oField.type === "Int32" || oField.type === "Double") {
				return new ObjectNumber({ number: "{" + p + "}" });
			}
			if (p === "createdAt" || p === "modifiedAt") {
				return new Text({ text: { path: p, formatter: formatter.timestamp } });
			}
			return new Text({ text: "{" + p + "}", wrapping: false });
		},

		/** Initial values of a new element from the field defaults. */
		defaults: function (oSetInfo) {
			var o = {};
			oSetInfo.fields.forEach(function (f) {
				if (f.readOnly) { return; }
				switch (f.type) {
					case "Boolean": o[f.name] = f.defaultValue === "true"; break;
					case "Int32": case "Double": o[f.name] = Number(f.defaultValue) || 0; break;
					case "StringCollection": o[f.name] = []; break;
					default: o[f.name] = f.defaultValue || "";
				}
			});
			return o;
		},

		/** Converts edited values back into the OData JSON types. */
		normalize: function (oSetInfo, oData) {
			var o = {};
			oSetInfo.fields.forEach(function (f) {
				if (f.readOnly || !(f.name in oData)) { return; }
				var v = oData[f.name];
				switch (f.type) {
					case "Int32": o[f.name] = v === "" || v === null ? 0 : parseInt(v, 10); break;
					case "Double": o[f.name] = v === "" || v === null ? 0 : parseFloat(v); break;
					case "Boolean": o[f.name] = !!v; break;
					case "Date": o[f.name] = v ? v : null; break;
					case "StringCollection": o[f.name] = Array.isArray(v) ? v : []; break;
					default: o[f.name] = v === null || v === undefined ? "" : String(v);
				}
			});
			return o;
		}
	};
});
