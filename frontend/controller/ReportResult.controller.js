sap.ui.define([
	"sap/ui/core/mvc/Controller",
	"sap/ui/model/json/JSONModel",
	"sap/m/Panel",
	"sap/m/Table",
	"sap/m/Column",
	"sap/m/ColumnListItem",
	"sap/m/Text",
	"sap/m/Title",
	"sap/m/MessageStrip",
	"sap/m/ObjectNumber",
	"sap/ui/core/format/DateFormat",
	"uim/eam/model/models"
], function (Controller, JSONModel, Panel, Table, Column, ColumnListItem, Text, Title, MessageStrip, ObjectNumber,
		DateFormat, models) {
	"use strict";

	var oDateFormat = DateFormat.getDateTimeInstance({ style: "medium" });

	/** Result of a report or of all reports of a report book: table and group summary per report, export. */
	return Controller.extend("uim.eam.controller.ReportResult", {
		onInit: function () {
			this.getView().setModel(new JSONModel({ title: "", subtitle: "", kind: "report", id: "", busy: false }), "view");
			this.getOwnerComponent().getRouter().getRoute("report").attachPatternMatched(this._onMatched, this);
		},

		_i18n: function (sKey, aArgs) {
			return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(sKey, aArgs);
		},

		_onMatched: function (oEvent) {
			var oArgs = oEvent.getParameter("arguments");
			var oView = this.getView().getModel("view");
			oView.setProperty("/kind", oArgs.kind);
			oView.setProperty("/id", decodeURIComponent(oArgs.id));
			this.onRefresh();
		},

		onRefresh: function () {
			var oView = this.getView().getModel("view");
			var oBox = this.byId("reportContent");
			oView.setProperty("/busy", true);
			oBox.destroyItems();
			models.runReport(oView.getProperty("/kind"), oView.getProperty("/id")).then(function (aResults) {
				var oFirst = aResults[0] || {};
				oView.setProperty("/title", aResults.length > 1 ? this._i18n("reportBookTitle", [aResults.length]) : oFirst.name);
				oView.setProperty("/subtitle", this._i18n("reportGenerated", [oFirst.generatedAt ? oDateFormat.format(new Date(oFirst.generatedAt)) : ""]));
				aResults.forEach(function (r) { oBox.addItem(this._panel(r, aResults.length > 1)); }.bind(this));
			}.bind(this)).catch(function (oError) {
				oBox.addItem(new MessageStrip({ text: oError.message, type: "Error", showIcon: true }));
			}).finally(function () {
				oView.setProperty("/busy", false);
			});
		},

		_panel: function (r, bTitled) {
			var oPanel = new Panel({ expandable: bTitled, expanded: true, headerText: bTitled ? r.name : "" });
			var sInfo = this._i18n("reportInfo", [r.setLabel, r.totalCount]) + (r.filter ? " · " + this._i18n("reportFilter", [r.filter]) : "");
			oPanel.addContent(new Text({ text: (r.description ? r.description + "\n" : "") + sInfo }).addStyleClass("sapUiSmallMarginBottom"));
			oPanel.addContent(this._table(r.columns.map(function (c) { return { label: c.label, numeric: c.type === "Int32" || c.type === "Double" }; }),
				r.rows, "reportRows"));
			if (r.groups && r.groups.length) {
				oPanel.addContent(new Title({ text: this._i18n("reportSummary", [r.groupLabel]), level: "H4" }).addStyleClass("sapUiMediumMarginTop sapUiSmallMarginBottom"));
				var aCols = [{ label: r.groupLabel }, { label: this._i18n("reportCount"), numeric: true }];
				if (r.sumField) { aCols.push({ label: r.sumLabel, numeric: true }); }
				oPanel.addContent(this._table(aCols, r.groups.map(function (g) {
					return [g.value, String(g.count)].concat(r.sumField ? [g.sum.toLocaleString()] : []);
				}), "reportGroups"));
			}
			return oPanel;
		},

		_table: function (aCols, aRows, sClass) {
			var oTable = new Table({ growing: true, growingThreshold: 100, noDataText: this._i18n("reportNoRows") }).addStyleClass(sClass);
			aCols.forEach(function (c) {
				oTable.addColumn(new Column({ header: new Text({ text: c.label, wrapping: true }), hAlign: c.numeric ? "End" : "Begin" }));
			});
			oTable.setModel(new JSONModel({ rows: aRows.map(function (r) { return { c: r }; }) }));
			oTable.bindItems({
				path: "/rows",
				factory: function (sId, oCtx) {
					return new ColumnListItem(sId, { cells: oCtx.getProperty("c").map(function (v, i) {
						return aCols[i] && aCols[i].numeric ? new ObjectNumber({ number: v }) : new Text({ text: v });
					}) });
				}
			});
			return oTable;
		},

		onExport: function (oEvent) {
			var oView = this.getView().getModel("view");
			window.location.href = models.reportExportUrl(oView.getProperty("/kind"), oView.getProperty("/id"), oEvent.getParameter("item").getKey());
		},

		onClose: function () {
			window.history.back();
		}
	});
});
