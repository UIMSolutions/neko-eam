sap.ui.define([
	"sap/ui/core/mvc/Controller",
	"sap/ui/core/Fragment",
	"sap/ui/core/Theming",
	"sap/base/i18n/Localization",
	"uim/eam/model/models",
	"uim/eam/model/auth",
	"uim/eam/controller/PasswordHelper"
], function (Controller, Fragment, Theming, Localization, models, auth, PasswordHelper) {
	"use strict";

	var STORAGE_THEME = "uim.eam.theme";
	var SUGGEST_DELAY = 200;
	var SUGGEST_TOP = 8;

	return Controller.extend("uim.eam.controller.App", {
		onInit: function () {
			var oComponent = this.getOwnerComponent();
			this.getView().addStyleClass(oComponent.getContentDensityClass());
			var oUi = oComponent.getModel("ui");
			oUi.setProperty("/language", Localization.getLanguage().substring(0, 2) === "de" ? "de" : "en");
			var sTheme = null;
			try { sTheme = window.localStorage.getItem(STORAGE_THEME); } catch (e) { /* storage blocked */ }
			if (sTheme) { Theming.setTheme(sTheme); }
			oUi.setProperty("/theme", sTheme || Theming.getTheme());
			// keep the side navigation selection in sync with the route
			oComponent.getRouter().attachRouteMatched(function (oEvent) {
				var sRoute = oEvent.getParameter("name");
				var oArgs = oEvent.getParameter("arguments");
				oUi.setProperty("/navKey", sRoute === "list" || sRoute === "detail" ? oArgs.set : sRoute);
				if (sRoute === "search") {
					// search results belong to no navigation entry
					this.byId("sideNavigation").setSelectedItem(null);
				}
			}.bind(this));
			oComponent.whenUserReady().then(this._applyPermissions.bind(this));
			this._oPassword = new PasswordHelper(this.getView());
			// the password was set by an administrator: ask for a new one right after signing in
			oComponent.whenUserReady().then(function () {
				var oUser = oComponent.getModel("user");
				if (oUser.getProperty("/mustChangePassword") && oUser.getProperty("/passwordChangeable")) {
					this._oPassword.openOwn(true);
				}
			}.bind(this));
		},

		/** Only entity sets the user may read are offered in the side navigation (empty groups are hidden). */
		_applyPermissions: function () {
			var oComponent = this.getOwnerComponent();
			oComponent.whenModelReady().then(function () {
				var aSets = (oComponent.getModel("meta").getProperty("/sets") || []).map(function (o) { return o.name; });
				this.byId("sideNavigation").getItem().getItems().forEach(function (oGroup) {
					var aChildren = oGroup.getItems();
					if (!aChildren.length) { return; }
					var bAny = false;
					aChildren.forEach(function (oItem) {
						var sKey = oItem.getKey();
						var oUser = oComponent.getModel("user");
						var bVisible = sKey === "backups" ? !!oUser.getProperty("/canBackup")
							: sKey === "tenants" ? !!oUser.getProperty("/systemAdministrator")
							: aSets.indexOf(sKey) < 0 || oComponent.canRead(sKey);
						oItem.setVisible(bVisible);
						bAny = bAny || bVisible;
					});
					oGroup.setVisible(bAny);
				});
			}.bind(this));
		},

		/** Switches the tenant (Mandant) and reloads the app with its data and rights. */
		onTenantChange: function (oEvent) {
			models.switchTenant(oEvent.getParameter("selectedItem").getKey());
			window.location.hash = "";
			window.location.reload();
		},

		/** Local development: switch to another repository user (reloads the app with the new rights). */
		onActAs: function (oEvent) {
			models.actAs(oEvent.getParameter("selectedItem").getKey());
			window.location.reload();
		},

		onToggleSideNavigation: function () {
			var oToolPage = this.byId("toolPage");
			oToolPage.setSideExpanded(!oToolPage.getSideExpanded());
		},

		onHome: function () {
			this.getOwnerComponent().getRouter().navTo("overview");
		},

		onNotifications: function () {
			this.getOwnerComponent().getRouter().navTo("analysis");
		},

		onNavItemSelect: function (oEvent) {
			var sKey = oEvent.getParameter("item").getKey();
			var oRouter = this.getOwnerComponent().getRouter();
			switch (sKey) {
				case "overview":
				case "analysis":
				case "backups":
				case "tenants":
					oRouter.navTo(sKey);
					break;
				case "extCockpit":
					window.open("web", "_blank");
					break;
				case "extMetadata":
					window.open(this.getOwnerComponent().getServiceUrl() + "$metadata", "_blank");
					break;
				default:
					if (sKey.indexOf("grp") !== 0) {
						oRouter.navTo("list", { set: sKey });
					}
			}
			if (this.getOwnerComponent().getModel("device").getProperty("/system/phone")) {
				this.byId("toolPage").setSideExpanded(false);
			}
		},

		onAvatarPressed: function (oEvent) {
			var oAvatar = oEvent.getParameter("avatar") || this.byId("userAvatar");
			if (!this._pProfile) {
				this._pProfile = Fragment.load({ id: this.getView().getId(), name: "uim.eam.view.UserProfile", controller: this })
					.then(function (oPopover) {
						this.getView().addDependent(oPopover);
						return oPopover;
					}.bind(this));
			}
			this._pProfile.then(function (oPopover) {
				if (oPopover.isOpen()) { oPopover.close(); } else { oPopover.openBy(oAvatar); }
			});
		},

		onThemeChange: function (oEvent) {
			var sTheme = oEvent.getParameter("selectedItem").getKey();
			Theming.setTheme(sTheme);
			try { window.localStorage.setItem(STORAGE_THEME, sTheme); } catch (e) { /* storage blocked */ }
		},

		onLanguageChange: function (oEvent) {
			var sLanguage = oEvent.getParameter("item").getKey();
			var oUrl = new URL(window.location.href);
			oUrl.searchParams.set("sap-language", sLanguage);
			window.location.href = oUrl.toString();
		},

		onChangePassword: function () {
			this._closeProfile();
			this._oPassword.openOwn(!!this.getOwnerComponent().getModel("user").getProperty("/mustChangePassword"));
		},

		/** Local sign-in: end the session, then the logout view. XSUAA: the approuter's logout endpoint. */
		onSignOut: function () {
			this._closeProfile();
			if (this.getOwnerComponent().getModel("user").getProperty("/authMode") !== "local") {
				window.location.href = "do/logout";
				return;
			}
			this.getView().setBusy(true);
			models.signOut().catch(function () { /* the session ends with its timeout anyway */ }).then(function () {
				window.location.replace(auth.LOGOUT_PAGE);
			});
		},

		_closeProfile: function () {
			if (this._pProfile) { this._pProfile.then(function (oPopover) { oPopover.close(); }); }
		},

		// ---- central search (shell bar)

		/** Type-ahead: the best hits of all entity sets as suggestions (debounced, stale responses ignored). */
		onSuggest: function (oEvent) {
			var sValue = (oEvent.getParameter("suggestValue") || "").trim();
			var oSearch = this.getOwnerComponent().getModel("search");
			clearTimeout(this._iSuggestTimer);
			if (sValue.length < 2) {
				oSearch.setProperty("/suggestions", []);
				return;
			}
			this._iSuggestTimer = setTimeout(function () {
				var iRequest = this._iSuggestRequest = (this._iSuggestRequest || 0) + 1;
				models.search(sValue, SUGGEST_TOP).then(function (aHits) {
					if (iRequest !== this._iSuggestRequest) { return; }
					oSearch.setProperty("/suggestions", aHits.map(this._toSuggestion.bind(this)));
					this.byId("searchManager").suggest();
				}.bind(this)).catch(function () {
					oSearch.setProperty("/suggestions", []);
				});
			}.bind(this), SUGGEST_DELAY);
		},

		_toSuggestion: function (oHit) {
			var oBundle = this.getOwnerComponent().getModel("i18n").getResourceBundle();
			var sType = oBundle.getText("set" + oHit.setName);
			return {
				key: JSON.stringify([oHit.setName, oHit.id]),
				name: oHit.name,
				icon: "sap-icon://" + oHit.icon,
				description: oHit.matchedField ? sType + " · " + oHit.matchedField : sType
			};
		},

		/** Enter opens the result page; a chosen suggestion opens the object page directly. */
		onSearch: function (oEvent) {
			var oRouter = this.getOwnerComponent().getRouter();
			var oItem = oEvent.getParameter("suggestionItem");
			var sQuery = (oEvent.getParameter("query") || "").trim();
			if (oEvent.getParameter("clearButtonPressed")) { return; }
			clearTimeout(this._iSuggestTimer);
			if (oItem) {
				var aKey = JSON.parse(oItem.getKey());
				oRouter.navTo("detail", { set: aKey[0], id: encodeURIComponent(aKey[1]) });
			} else if (sQuery) {
				oRouter.navTo("search", { query: encodeURIComponent(sQuery) });
			}
		},

		onExportArchiMate: function () {
			window.open("api/v1/export/archimate", "_blank");
		}
	});
});
