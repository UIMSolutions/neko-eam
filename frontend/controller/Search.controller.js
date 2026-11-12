sap.ui.define([
	"sap/ui/core/mvc/Controller",
	"sap/ui/model/json/JSONModel",
	"uim/eam/model/models"
], function (Controller, JSONModel, models) {
	"use strict";

	var MAX_HITS = 200;

	/** Result page of the central shell bar search, with a filter by element type. */
	return Controller.extend("uim.eam.controller.Search", {
		onInit: function () {
			this.getView().setModel(new JSONModel({ query: "", type: "", hits: [], visible: [], facets: [], subtitle: "", noData: "", busy: false }), "view");
			this.getOwnerComponent().getRouter().getRoute("search").attachPatternMatched(this._onMatched, this);
		},

		_i18n: function (sKey, aArgs) {
			return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(sKey, aArgs);
		},

		_onMatched: function (oEvent) {
			var sQuery = decodeURIComponent(oEvent.getParameter("arguments").query);
			var oView = this.getView().getModel("view");
			oView.setProperty("/query", sQuery);
			oView.setProperty("/type", "");
			oView.setProperty("/busy", true);
			var iRequest = this._iRequest = (this._iRequest || 0) + 1;
			models.search(sQuery, MAX_HITS).then(function (aHits) {
				if (iRequest !== this._iRequest) { return; }
				this._setHits(sQuery, aHits);
			}.bind(this)).catch(function (oError) {
				oView.setProperty("/noData", oError.message);
				oView.setProperty("/hits", []);
				oView.setProperty("/visible", []);
			}).finally(function () {
				oView.setProperty("/busy", false);
			});
		},

		_setHits: function (sQuery, aHits) {
			var oView = this.getView().getModel("view");
			var mCounts = {};
			aHits.forEach(function (oHit) {
				oHit.typeText = this._i18n("set" + oHit.setName);
				var sMatch = oHit.matchedField ? this._i18n("searchMatchedIn", [oHit.matchedField, oHit.snippet]) : "";
				oHit.details = [oHit.id, sMatch || oHit.description].filter(Boolean).join(" · ");
				mCounts[oHit.setName] = (mCounts[oHit.setName] || 0) + 1;
			}, this);
			var aFacets = [{ key: "", text: this._i18n("searchAllTypes", [aHits.length]) }].concat(
				Object.keys(mCounts).sort().map(function (sSet) {
					return { key: sSet, text: this._i18n("set" + sSet) + " (" + mCounts[sSet] + ")" };
				}, this));
			oView.setProperty("/hits", aHits);
			oView.setProperty("/facets", aFacets);
			oView.setProperty("/subtitle", this._i18n("searchResultsFor", [sQuery]) + " – " + this._i18n("searchHits", [aHits.length]));
			oView.setProperty("/noData", this._i18n("searchNoResults", [sQuery]));
			this.onTypeChange();
		},

		onTypeChange: function () {
			var oView = this.getView().getModel("view");
			var sType = oView.getProperty("/type");
			oView.setProperty("/visible", oView.getProperty("/hits").filter(function (oHit) {
				return !sType || oHit.setName === sType;
			}));
		},

		onSearch: function (oEvent) {
			var sQuery = (oEvent.getParameter("query") || "").trim();
			if (sQuery) {
				this.getOwnerComponent().getRouter().navTo("search", { query: encodeURIComponent(sQuery) });
			}
		},

		onOpen: function (oEvent) {
			var oHit = oEvent.getSource().getBindingContext("view").getObject();
			this.getOwnerComponent().getRouter().navTo("detail", { set: oHit.setName, id: encodeURIComponent(oHit.id) });
		}
	});
});
