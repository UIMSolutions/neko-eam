sap.ui.define([
	"sap/ui/core/mvc/Controller",
	"uim/eam/model/formatter",
	"uim/eam/controller/TransferHelper"
], function (Controller, formatter, TransferHelper) {
	"use strict";

	return Controller.extend("uim.eam.controller.Overview", {
		formatter: formatter,

		onInit: function () {
			this._oTransfer = new TransferHelper(this.getView());
		},

		/** Whole repository as one workbook, one sheet per element type. */
		onExportAll: function () {
			this._oTransfer.download(null, "xlsx");
		},

		onImportAll: function () {
			this._oTransfer.openImport(null);
		},

		onRefresh: function () {
			this.getOwnerComponent().refreshAnalysis();
		},

		onOpenSet: function (oEvent) {
			var sSet = oEvent.getSource().data("set");
			if (sSet) {
				this.getOwnerComponent().getRouter().navTo("list", { set: sSet });
			}
		},

		onShowAnalysis: function () {
			this.getOwnerComponent().getRouter().navTo("analysis");
		},

		onOpenAlertProduct: function (oEvent) {
			var sId = oEvent.getSource().getBindingContext("portfolio").getProperty("productId");
			this.getOwnerComponent().getRouter().navTo("detail", { set: "Products", id: encodeURIComponent(sId) });
		}
	});
});
