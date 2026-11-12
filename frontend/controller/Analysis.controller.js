sap.ui.define([
	"sap/ui/core/mvc/Controller",
	"uim/eam/model/formatter"
], function (Controller, formatter) {
	"use strict";

	return Controller.extend("uim.eam.controller.Analysis", {
		formatter: formatter,

		onRefresh: function () {
			this.getOwnerComponent().refreshAnalysis();
		},

		onOpenProduct: function (oEvent) {
			var sId = oEvent.getSource().getBindingContext("portfolio").getProperty("productId");
			this.getOwnerComponent().getRouter().navTo("detail", { set: "Products", id: encodeURIComponent(sId) });
		},

		onOpenApplication: function (oEvent) {
			var sId = oEvent.getSource().getBindingContext("portfolio").getProperty("applicationId");
			this.getOwnerComponent().getRouter().navTo("detail", { set: "Applications", id: encodeURIComponent(sId) });
		}
	});
});
