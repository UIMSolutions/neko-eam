sap.ui.define([
	"sap/ui/core/UIComponent",
	"sap/ui/Device",
	"sap/ui/model/json/JSONModel",
	"uim/eam/model/models"
], function (UIComponent, Device, JSONModel, models) {
	"use strict";

	return UIComponent.extend("uim.eam.Component", {
		metadata: {
			manifest: "json",
			interfaces: ["sap.ui.core.IAsyncContentCreation"]
		},

		init: function () {
			UIComponent.prototype.init.apply(this, arguments);
			this._sServiceUrl = this.getManifestEntry("/sap.app/dataSources/mainService/uri");
			this.setModel(models.createDeviceModel(), "device");
			this.setModel(models.createUiModel(), "ui");
			this.setModel(models.createPortfolioModel(), "portfolio");
			this.setModel(models.createUserModel(), "user");
			this.setModel(models.createMetaModel(), "meta");
			this.setModel(models.createLookupModel(), "lookup");
			this.setModel(new JSONModel({ suggestions: [] }), "search");
			// the meta model (labels, groups, field types) is needed by the generic list / detail pages
			this._pUserReady = models.loadUser(this.getModel("user"));
			this._pModelReady = Promise.all([models.loadMeta(this.getModel("meta")), this._pUserReady]).then(function () {
				return models.loadLookup(this.getModel("lookup"), this.getModel("meta"), this._sServiceUrl, this.canRead.bind(this));
			}.bind(this));
			this.getRouter().initialize();
		},

		/** Reloads the signed-in user (e.g. after a tenant was created: new entry in the tenant selector). */
		reloadUser: function () {
			this._pUserReady = models.loadUser(this.getModel("user"));
			return this._pUserReady;
		},

		/** Resolves when the signed-in user and the user's rights are loaded. */
		whenUserReady: function () {
			return this._pUserReady;
		},

		/** Rights of the signed-in user on an entity set: { read, create, update, remove }. */
		rightsOf: function (sSet) {
			var oUser = this.getModel("user");
			if (oUser.getProperty("/unrestricted")) {
				return { read: true, create: true, update: true, remove: true };
			}
			return oUser.getProperty("/rights/" + sSet) || { read: false, create: false, update: false, remove: false };
		},

		canRead: function (sSet) {
			return this.rightsOf(sSet).read;
		},

		/** Publishes the rights on sSet to the ui model (buttons and editable fields of list / object pages). */
		applySetRights: function (sSet, bNew) {
			var r = this.rightsOf(sSet);
			var oUi = this.getModel("ui");
			oUi.setProperty("/canCreate", r.create);
			oUi.setProperty("/canUpdate", r.update);
			oUi.setProperty("/canDelete", r.remove);
			oUi.setProperty("/canImport", r.create || r.update);
			oUi.setProperty("/readOnly", bNew ? !r.create : !r.update);
		},

		/** Resolves when the meta model and the name lookup are loaded. */
		whenModelReady: function () {
			return this._pModelReady;
		},

		/** OData service root, e.g. "odata/v4/eam/". */
		getServiceUrl: function () {
			return this._sServiceUrl;
		},

		/** Entity set description from /api/v1/model. */
		getSetInfo: function (sSet) {
			return (this.getModel("meta").getProperty("/sets") || []).find(function (o) { return o.name === sSet; });
		},

		/** Reloads analysis and name lookup after changes. */
		refreshAnalysis: function () {
			models.loadPortfolio(this.getModel("portfolio"));
			models.loadLookup(this.getModel("lookup"), this.getModel("meta"), this._sServiceUrl, this.canRead.bind(this));
		},

		getContentDensityClass: function () {
			return Device.support.touch ? "sapUiSizeCozy" : "sapUiSizeCompact";
		}
	});
});
