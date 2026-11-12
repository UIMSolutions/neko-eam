sap.ui.define([
	"sap/ui/core/mvc/Controller",
	"sap/ui/model/json/JSONModel",
	"sap/ui/model/Filter",
	"sap/ui/model/FilterOperator",
	"sap/ui/model/Sorter",
	"sap/m/Column",
	"sap/m/ColumnListItem",
	"sap/m/Text",
	"sap/m/MessageBox",
	"sap/m/MessageToast",
	"uim/eam/model/models",
	"uim/eam/model/fieldFactory",
	"uim/eam/model/formatter",
	"uim/eam/controller/TransferHelper"
], function (Controller, JSONModel, Filter, FilterOperator, Sorter, Column, ColumnListItem, Text, MessageBox, MessageToast,
	models, fieldFactory, formatter, TransferHelper) {
	"use strict";

	/** Generic list page of one entity set; columns come from the @ListColumn fields of the meta model. */
	return Controller.extend("uim.eam.controller.ElementList", {
		formatter: formatter,

		onInit: function () {
			this.getView().setModel(new JSONModel({ title: "", subtitle: "", tableTitle: "", query: "", hasSelection: false }), "view");
			this.getOwnerComponent().getRouter().getRoute("list").attachPatternMatched(this._onRouteMatched, this);
			this._oTransfer = new TransferHelper(this.getView());
		},

		/** Menu key "xlsx", "csv" or "csv;" (semicolon separated CSV for Excel with German settings). */
		onExport: function (oEvent) {
			var sKey = oEvent.getParameter("item").getKey();
			this._oTransfer.download(this._sSet, sKey.substring(0, 3) === "csv" ? "csv" : "xlsx", sKey === "csv;" ? ";" : null);
		},

		onImport: function () {
			this._oTransfer.openImport(this._sSet, function () {
				this.byId("elementTable").getBinding("items").refresh();
			}.bind(this));
		},

		_i18n: function (sKey, aArgs) {
			return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(sKey, aArgs);
		},

		_onRouteMatched: function (oEvent) {
			var sSet = oEvent.getParameter("arguments").set;
			this.getOwnerComponent().whenModelReady().then(function () {
				var oInfo = this.getOwnerComponent().getSetInfo(sSet);
				if (!oInfo) {
					this.getOwnerComponent().getRouter().navTo("overview", {}, true);
					return;
				}
				this.getOwnerComponent().applySetRights(sSet, false);
				if (this._sSet !== sSet) {
					this._sSet = sSet;
					this._buildTable(oInfo);
				} else {
					this.byId("elementTable").getBinding("items").refresh();
				}
			}.bind(this));
		},

		_columnsOf: function (oInfo) {
			return oInfo.fields.filter(function (f) { return f.listColumn; });
		},

		_buildTable: function (oInfo) {
			var oTable = this.byId("elementTable");
			var oView = this.getView().getModel("view");
			var sLabel = this._i18n("set" + oInfo.name) || oInfo.label;
			oView.setData({ title: sLabel, subtitle: this._i18n("listSubtitle", [oInfo.fields.length]), tableTitle: sLabel, query: "", hasSelection: false });
			oTable.unbindItems();
			oTable.destroyColumns();
			var aFields = this._columnsOf(oInfo);
			aFields.forEach(function (f, i) {
				oTable.addColumn(new Column({
					header: new Text({ text: f.label, wrapping: true }),
					minScreenWidth: i < 3 ? "" : (i < 5 ? "Tablet" : "Desktop"),
					demandPopin: i >= 3,
					hAlign: f.type === "Int32" || f.type === "Double" ? "End" : "Begin"
				}));
			});
			var oTemplate = new ColumnListItem({
				type: "Navigation",
				press: this.onOpen.bind(this),
				cells: aFields.map(function (f) { return fieldFactory.createCell(f); })
			});
			var aSelect = ["id"].concat(aFields.map(function (f) { return f.name; }));
			oTable.bindItems({
				path: "/" + oInfo.name,
				parameters: { $count: true, $select: aSelect.join(",") },
				sorter: new Sorter("name"),
				template: oTemplate,
				templateShareable: false,
				events: { dataReceived: this._onDataReceived.bind(this) }
			});
			if (!this._bCollectionHook) {
				this._bCollectionHook = true;
				oTable.attachUpdateFinished(function () {
					fieldFactory.fillCollectionCells(oTable, this.getOwnerComponent().getModel("lookup"));
				}, this);
			}
		},

		_onDataReceived: function () {
			var oBinding = this.byId("elementTable").getBinding("items");
			var oView = this.getView().getModel("view");
			var iCount = oBinding.getCount();
			oView.setProperty("/tableTitle", oView.getProperty("/title") + (iCount !== undefined ? " (" + iCount + ")" : ""));
		},

		onSearch: function (oEvent) {
			var sQuery = oEvent.getParameter("query");
			var aFilters = sQuery ? [new Filter({ path: "name", operator: FilterOperator.Contains, value1: sQuery, caseSensitive: false })] : [];
			this.byId("elementTable").getBinding("items").filter(aFilters);
		},

		onSelectionChange: function () {
			this.getView().getModel("view").setProperty("/hasSelection", !!this.byId("elementTable").getSelectedItem());
		},

		onRefresh: function () {
			this.byId("elementTable").getBinding("items").refresh();
			this.getOwnerComponent().refreshAnalysis();
		},

		onOpen: function (oEvent) {
			var sId = oEvent.getSource().getBindingContext().getProperty("id");
			this.getOwnerComponent().getRouter().navTo("detail", { set: this._sSet, id: encodeURIComponent(sId) });
		},

		onCreate: function () {
			this.getOwnerComponent().getRouter().navTo("detail", { set: this._sSet, id: "new" });
		},

		onDelete: function () {
			var oItem = this.byId("elementTable").getSelectedItem();
			if (!oItem) {
				MessageToast.show(this._i18n("selectFirst"));
				return;
			}
			var oContext = oItem.getBindingContext();
			MessageBox.confirm(this._i18n("deleteConfirmNamed", [oContext.getProperty("name")]), {
				onClose: function (sAction) {
					if (sAction !== MessageBox.Action.OK) { return; }
					oContext.delete("$direct").then(function () {
						MessageToast.show(this._i18n("deleted"));
						this.getView().getModel("view").setProperty("/hasSelection", false);
						this.getOwnerComponent().refreshAnalysis();
					}.bind(this), function (oError) {
						if (!oError.canceled) {
							MessageBox.error(oError.message);
						}
					});
				}.bind(this)
			});
		}
	});
});
