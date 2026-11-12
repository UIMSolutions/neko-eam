sap.ui.define([
	"sap/ui/base/Object",
	"sap/ui/core/Fragment",
	"sap/ui/model/json/JSONModel",
	"sap/m/MessageBox",
	"sap/m/MessageToast",
	"uim/eam/model/models"
], function (BaseObject, Fragment, JSONModel, MessageBox, MessageToast, models) {
	"use strict";

	/** Same minimum as the server's password policy (the server has the final word). */
	var MIN_LENGTH = 10;

	/**
	 * Password dialog of the local sign-in:
	 * - "own":   the signed-in user changes the own password (profile; forced after an administrator reset)
	 * - "admin": a user administrator sets or removes the password of a repository user (Users object page)
	 */
	return BaseObject.extend("uim.eam.controller.PasswordHelper", {
		constructor: function (oView) {
			BaseObject.call(this);
			this._oView = oView;
			this._oComponent = oView.getController().getOwnerComponent();
			this._oModel = new JSONModel();
		},

		/** Change the own password; bForced: the administrator set it, the user should choose a new one now. */
		openOwn: function (bForced) {
			return this._open({
				mode: "own",
				forced: !!bForced,
				title: this._i18n("passwordChangeTitle"),
				hint: bForced ? this._i18n("passwordForcedHint") : "",
				hintType: "Warning"
			});
		},

		/** Set (or remove) the password of the repository user sUserName (sName: display name). */
		openForUser: function (sUserName, sName) {
			var oDone = this._open({
				mode: "admin",
				userName: sUserName,
				title: this._i18n("passwordSetTitle", [sName || sUserName]),
				hint: "",
				hintType: "Information",
				mustChange: true,
				hasPassword: false
			});
			this._oModel.setProperty("/busy", true);
			models.getUserPassword(sUserName).then(function (oState) {
				this._oModel.setProperty("/hasPassword", !!oState.hasPassword);
				this._oModel.setProperty("/hint", this._i18n(oState.hasPassword ? "passwordHasOne" : "passwordHasNone", [sUserName]));
			}.bind(this)).catch(function () { /* the save call reports missing rights */ }).finally(function () {
				this._oModel.setProperty("/busy", false);
			}.bind(this));
			return oDone;
		},

		// ---- dialog event handlers (controller of the fragment)

		onPasswordInput: function () {
			["current", "password", "repeat"].forEach(function (s) { this._oModel.setProperty("/" + s + "State", "None"); }, this);
		},

		onPasswordSave: function () {
			var m = this._oModel;
			var oData = m.getData();
			var bOk = true;
			if (oData.mode === "own" && !oData.current) {
				m.setProperty("/currentState", "Error");
				m.setProperty("/currentStateText", this._i18n("passwordRequired"));
				bOk = false;
			}
			if ((oData.password || "").length < MIN_LENGTH) {
				m.setProperty("/passwordState", "Error");
				m.setProperty("/passwordStateText", this._i18n("passwordTooShort", [MIN_LENGTH]));
				bOk = false;
			} else if (oData.password !== oData.repeat) {
				m.setProperty("/repeatState", "Error");
				bOk = false;
			}
			if (!bOk) { return; }
			var sServiceUrl = this._oComponent.getServiceUrl();
			var pSave = oData.mode === "own"
				? models.changePassword(sServiceUrl, oData.current, oData.password)
				: models.setUserPassword(sServiceUrl, oData.userName, oData.password, oData.mustChange);
			m.setProperty("/busy", true);
			pSave.then(function () {
				if (oData.mode === "own") { this._oComponent.getModel("user").setProperty("/mustChangePassword", false); }
				MessageToast.show(this._i18n(oData.mode === "own" ? "passwordChanged" : "passwordSet"));
				this._close();
			}.bind(this)).catch(this._showError.bind(this)).finally(function () {
				m.setProperty("/busy", false);
			});
		},

		onPasswordRemove: function () {
			var sUserName = this._oModel.getProperty("/userName");
			MessageBox.confirm(this._i18n("passwordRemoveConfirm", [sUserName]), {
				onClose: function (sAction) {
					if (sAction !== MessageBox.Action.OK) { return; }
					this._oModel.setProperty("/busy", true);
					models.removeUserPassword(this._oComponent.getServiceUrl(), sUserName).then(function () {
						MessageToast.show(this._i18n("passwordRemoved"));
						this._close();
					}.bind(this)).catch(this._showError.bind(this)).finally(function () {
						this._oModel.setProperty("/busy", false);
					}.bind(this));
				}.bind(this)
			});
		},

		onPasswordCancel: function () {
			this._close();
		},

		// ---- internals

		_open: function (oData) {
			this._oModel.setData(Object.assign({
				current: "", password: "", repeat: "", busy: false,
				currentState: "None", passwordState: "None", repeatState: "None", currentStateText: "", passwordStateText: ""
			}, oData));
			if (!this._pDialog) {
				this._pDialog = Fragment.load({ id: this._oView.getId() + "--pw", name: "uim.eam.view.PasswordDialog", controller: this })
					.then(function (oDialog) {
						oDialog.setModel(this._oModel, "pw");
						this._oView.addDependent(oDialog);
						this._attr("passwordCurrent", "current-password");
						this._attr("passwordNew", "new-password");
						this._attr("passwordRepeat", "new-password");
						return oDialog;
					}.bind(this));
			}
			return this._pDialog.then(function (oDialog) {
				oDialog.open();
				var sFirst = oData.mode === "own" ? "passwordCurrent" : "passwordNew";
				oDialog.attachEventOnce("afterOpen", function () { this._byId(sFirst).focus(); }, this);
				return oDialog;
			}.bind(this));
		},

		_close: function () {
			this._oModel.setProperty("/current", "");
			this._oModel.setProperty("/password", "");
			this._oModel.setProperty("/repeat", "");
			this._pDialog.then(function (oDialog) { oDialog.close(); });
		},

		/** Server messages at the field they belong to (target), otherwise in a message box. */
		_showError: function (oError) {
			var m = this._oModel;
			if (oError.target === "currentPassword") {
				m.setProperty("/currentState", "Error");
				m.setProperty("/currentStateText", oError.message);
			} else if (oError.target === "password") {
				m.setProperty("/passwordState", "Error");
				m.setProperty("/passwordStateText", oError.message);
			} else {
				MessageBox.error(oError.message);
			}
		},

		_byId: function (sId) {
			return Fragment.byId(this._oView.getId() + "--pw", sId);
		},

		/** Lets password managers offer / store the right entries (registered once per input). */
		_attr: function (sId, sAutocomplete) {
			var oInput = this._byId(sId);
			oInput.addEventDelegate({
				onAfterRendering: function () {
					var oDom = oInput.getDomRef("inner");
					if (oDom) { oDom.setAttribute("autocomplete", sAutocomplete); }
				}
			});
		},

		_i18n: function (sKey, aArgs) {
			return this._oComponent.getModel("i18n").getResourceBundle().getText(sKey, aArgs);
		}
	});
});
