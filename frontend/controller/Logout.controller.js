sap.ui.define([
	"sap/ui/core/mvc/Controller"
], function (Controller) {
	"use strict";

	/**
	 * Shown after signing out - locally (the app ended the session) and with the SAP approuter (its logoutPage).
	 * Makes no backend calls: with the approuter the user is no longer authenticated here.
	 */
	return Controller.extend("uim.eam.controller.Logout", {
		onAfterRendering: function () {
			this.byId("signInAgainButton").focus();
		},

		/** The app sends signed-out users to the sign-in (login view or identity provider). */
		onSignInAgain: function () {
			window.location.replace("index.html");
		}
	});
});
