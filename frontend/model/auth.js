sap.ui.define([], function () {
	"use strict";

	/** Pages of the local sign-in (served next to index.html). */
	var LOGIN_PAGE = "login.html";
	var LOGOUT_PAGE = "logout.html";

	function body(oResponse) {
		return oResponse.json().catch(function () { return {}; }).then(function (oBody) {
			if (!oResponse.ok) {
				var oErr = (oBody && oBody.error) || {};
				var oError = new Error(oErr.message || ("HTTP " + oResponse.status));
				oError.status = oResponse.status;
				oError.code = oErr.code;
				oError.target = oErr.target;
				oError.retryAfter = parseInt(oResponse.headers.get("Retry-After"), 10) || 0;
				throw oError;
			}
			return oBody;
		});
	}

	return {
		LOGIN_PAGE: LOGIN_PAGE,
		LOGOUT_PAGE: LOGOUT_PAGE,

		/**
		 * Where to continue after signing in. Only targets of this app are accepted (no open redirect):
		 * an app route ("#/sets/Products") or the web cockpit ("/web/..."); everything else opens the app.
		 */
		safeTarget: function (sReturnTo) {
			var s = typeof sReturnTo === "string" ? sReturnTo : "";
			if (/^#[^\s]*$/.test(s) && s.length > 1) { return "index.html" + s; }
			if (/^\/web(\/[\w\-.%\/]*)?(\?[\w\-.%=&]*)?$/.test(s) && s.indexOf("//") < 0 && s.indexOf("..") < 0) { return s; }
			return "index.html";
		},

		/** URL of the login view that returns to the current app route afterwards. */
		loginUrl: function (sPage, sHash) {
			var sReturnTo = sHash && sHash !== "#" ? "?returnTo=" + encodeURIComponent(sHash) : "";
			return (sPage || LOGIN_PAGE) + sReturnTo;
		},

		/** { authMode: "none" | "local" | "xsuaa", signedIn, multiTenant } */
		info: function () {
			return fetch("auth/info", { credentials: "same-origin", headers: { "Accept": "application/json" } }).then(body);
		},

		/** Resolves with { userName, displayName, tenant, mustChangePassword }; rejects with status 401 / 403 / 429. */
		signIn: function (sUserName, sPassword, sTenant) {
			return fetch("auth/login", {
				method: "POST",
				credentials: "same-origin",
				headers: { "Content-Type": "application/json", "Accept": "application/json" },
				body: JSON.stringify({ userName: sUserName, password: sPassword, tenant: sTenant || "" })
			}).then(body);
		},

		/** Ends the session of the local sign-in (resolves also if there was none). */
		signOut: function () {
			return fetch("auth/logout", { method: "POST", credentials: "same-origin" }).then(function () { return null; });
		}
	};
});
