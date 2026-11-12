sap.ui.define([
	"sap/ui/core/mvc/Controller",
	"sap/ui/model/json/JSONModel",
	"uim/eam/model/auth"
], function (Controller, JSONModel, auth) {
	"use strict";

	var STORAGE_USER = "uim.eam.lastUser";
	var STORAGE_TENANT = "uim.eam.lastTenant";

	function remembered(sKey) {
		try { return window.localStorage.getItem(sKey) || ""; } catch (e) { return ""; }
	}

	function remember(sKey, sValue) {
		try { window.localStorage.setItem(sKey, sValue); } catch (e) { /* storage blocked */ }
	}

	return Controller.extend("uim.eam.controller.Login", {
		onInit: function () {
			var oParams = new URLSearchParams(window.location.search);
			this._sTarget = auth.safeTarget(oParams.get("returnTo"));
			var oModel = new JSONModel({
				userName: remembered(STORAGE_USER),
				password: "",
				tenant: remembered(STORAGE_TENANT),
				multiTenant: false,
				busy: true,
				message: oParams.get("reason") === "expired" ? this._text("loginSessionExpired") : "",
				messageType: "Information",
				userNameState: "None",
				passwordState: "None"
			});
			this.getView().setModel(oModel, "login");
			// help password managers and mobile keyboards
			this._attr("userName", { autocomplete: "username", autocapitalize: "none", spellcheck: "false" });
			this._attr("password", { autocomplete: "current-password" });
			this._attr("tenant", { autocomplete: "organization", autocapitalize: "none", spellcheck: "false" });
			// the form is only used by the local sign-in; otherwise (or when already signed in) continue
			auth.info().then(function (oInfo) {
				if (oInfo.authMode !== "local" || oInfo.signedIn) {
					window.location.replace(this._sTarget);
					return;
				}
				oModel.setProperty("/multiTenant", !!oInfo.multiTenant);
				oModel.setProperty("/busy", false);
				this._focus();
			}.bind(this)).catch(function () {
				// no backend sign-in here (e.g. behind the SAP approuter, which signs in itself)
				window.location.replace("index.html");
			});
		},

		onInputChange: function () {
			var oModel = this.getView().getModel("login");
			oModel.setProperty("/userNameState", "None");
			oModel.setProperty("/passwordState", "None");
		},

		onSignIn: function () {
			var oModel = this.getView().getModel("login");
			if (oModel.getProperty("/busy")) { return; }
			var sUser = (oModel.getProperty("/userName") || "").trim();
			var sPassword = oModel.getProperty("/password") || "";
			var sTenant = (oModel.getProperty("/tenant") || "").trim().toLowerCase();
			oModel.setProperty("/userNameState", sUser ? "None" : "Error");
			oModel.setProperty("/passwordState", sPassword ? "None" : "Error");
			if (!sUser || !sPassword) {
				this._show(this._text("loginMissing"), "Error");
				this._focus();
				return;
			}
			oModel.setProperty("/busy", true);
			auth.signIn(sUser, sPassword, oModel.getProperty("/multiTenant") ? sTenant : "").then(function () {
				remember(STORAGE_USER, sUser);
				remember(STORAGE_TENANT, sTenant);
				oModel.setProperty("/password", "");
				window.location.replace(this._sTarget);
			}.bind(this)).catch(function (oError) {
				oModel.setProperty("/busy", false);
				oModel.setProperty("/password", "");
				if (oError.status === 401) {
					oModel.setProperty("/passwordState", "Error");
					this._show(this._text("loginInvalid"), "Error");
				} else if (oError.status === 429) {
					this._show(this._text("loginLocked", [oError.retryAfter || 30]), "Warning");
				} else {
					this._show(oError.message || this._text("loginFailed"), "Error");
				}
				this.byId("password").focus();
			}.bind(this));
		},

		_show: function (sText, sType) {
			var oModel = this.getView().getModel("login");
			oModel.setProperty("/message", sText);
			oModel.setProperty("/messageType", sType);
		},

		/** Focus on the first empty field. */
		_focus: function () {
			var oModel = this.getView().getModel("login");
			var sId = oModel.getProperty("/userName") ? "password" : "userName";
			setTimeout(function () { this.byId(sId).focus(); }.bind(this), 0);
		},

		/** Sets attributes on the inner <input> whenever the control renders. */
		_attr: function (sId, mAttributes) {
			var oInput = this.byId(sId);
			oInput.addEventDelegate({
				onAfterRendering: function () {
					var oDom = oInput.getDomRef("inner");
					if (!oDom) { return; }
					Object.keys(mAttributes).forEach(function (k) { oDom.setAttribute(k, mAttributes[k]); });
				}
			});
		},

		_text: function (sKey, aArgs) {
			return this.getView().getModel("i18n").getResourceBundle().getText(sKey, aArgs);
		}
	});
});
