sap.ui.define([
	"sap/ui/core/UIComponent",
	"sap/ui/Device",
	"sap/ui/model/json/JSONModel",
	"uim/eam/model/models",
	"uim/eam/model/notifications",
	"uim/eam/model/formatter"
], function (UIComponent, Device, JSONModel, models, notifications, formatter) {
	"use strict";

	/** Notifications are polled while the browser tab is visible. */
	var NOTIFICATION_POLL_MS = 60000;

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
			this.setModel(new JSONModel({ unread: 0, badge: "", alerts: [], activities: [], busy: false }), "notifications");
			this.setModel(new JSONModel({ open: false, title: "", sections: [], fields: [], fieldsTitle: "" }), "help");
			// the meta model (labels, groups, field types) is needed by the generic list / detail pages
			this._pUserReady = models.loadUser(this.getModel("user"));
			this._pModelReady = Promise.all([models.loadMeta(this.getModel("meta")), this._pUserReady]).then(function () {
				return models.loadLookup(this.getModel("lookup"), this.getModel("meta"), this._sServiceUrl, this.canRead.bind(this));
			}.bind(this));
			this.getRouter().initialize();
			this._pModelReady.then(function () { this.refreshNotifications(); }.bind(this));
			this._iNotificationTimer = setInterval(function () {
				if (!document.hidden) { this.refreshNotifications(); }
			}.bind(this), NOTIFICATION_POLL_MS);
			this._fnVisible = function () { if (!document.hidden) { this.refreshNotifications(); } }.bind(this);
			document.addEventListener("visibilitychange", this._fnVisible);
		},

		exit: function () {
			clearInterval(this._iNotificationTimer);
			document.removeEventListener("visibilitychange", this._fnVisible);
		},

		// ---- notifications (shell bar)

		/** Loads the notifications of the signed-in user (bBusy: show the busy indicator). */
		refreshNotifications: function (bBusy) {
			var oModel = this.getModel("notifications");
			if (bBusy) { oModel.setProperty("/busy", true); }
			return models.loadNotifications().then(this.applyNotifications.bind(this)).catch(function () {
				/* no notifications for this caller (e.g. signed out) - keep what is shown */
			}).finally(function () {
				oModel.setProperty("/busy", false);
			});
		},

		/** Shows a notification list of the backend ({unread, items}). */
		applyNotifications: function (oList) {
			var oBundle = this.getModel("i18n").getResourceBundle();
			var that = this;
			var oTexts = {
				text: function (sKey, aArgs) { return oBundle.getText(sKey, aArgs, true) || null; },
				typeLabel: function (sSet) {
					var oInfo = that.getSetInfo(sSet);
					return (oInfo && oBundle.getText("type" + oInfo.typeName, undefined, true)) || oBundle.getText("set" + sSet, undefined, true) || sSet;
				},
				fieldLabel: function (sSet, sField) {
					var oInfo = that.getSetInfo(sSet);
					var oField = oInfo && oInfo.fields.find(function (f) { return f.name === sField; });
					return oField ? oField.label : sField;
				},
				date: formatter.date,
				timestamp: formatter.timestamp
			};
			var oView = notifications.toViewModel(oList, oTexts);
			var oModel = this.getModel("notifications");
			["unread", "badge", "alerts", "activities"].forEach(function (k) { oModel.setProperty("/" + k, oView[k]); });
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
