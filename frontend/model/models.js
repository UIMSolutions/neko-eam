sap.ui.define([
	"sap/ui/model/json/JSONModel",
	"sap/ui/Device"
], function (JSONModel, Device) {
	"use strict";

	var API = "api/v1/";
	var sCsrfToken = null;

	function json(oResponse) {
		if (oResponse.status === 204) { return null; }
		return oResponse.json().catch(function () { return {}; }).then(function (oBody) {
			if (!oResponse.ok) {
				var oErr = (oBody && oBody.error) || {};
				var oError = new Error(oErr.message || ("HTTP " + oResponse.status));
				oError.status = oResponse.status;
				oError.target = oErr.target;
				throw oError;
			}
			return oBody;
		});
	}

	/** CSRF token for modifying requests (required by the approuter, ignored by the local backend). */
	function fetchToken(sServiceUrl) {
		return fetch(sServiceUrl, { method: "HEAD", headers: { "X-CSRF-Token": "Fetch" }, credentials: "same-origin" })
			.then(function (oResponse) {
				sCsrfToken = oResponse.headers.get("X-CSRF-Token") || "unsafe";
				return sCsrfToken;
			});
	}

	function modify(sServiceUrl, sMethod, sUrl, oBody, bRetried) {
		return send(sServiceUrl, sMethod, sUrl, oBody ? JSON.stringify(oBody) : undefined, "application/json", bRetried);
	}

	/** Modifying request with CSRF token; the token is fetched again once if the approuter rejects it. */
	function send(sServiceUrl, sMethod, sUrl, vBody, sContentType, bRetried) {
		var pToken = sCsrfToken ? Promise.resolve(sCsrfToken) : fetchToken(sServiceUrl);
		return pToken.then(function (sToken) {
			return fetch(sUrl, {
				method: sMethod,
				credentials: "same-origin",
				headers: { "Content-Type": sContentType, "Accept": "application/json", "X-CSRF-Token": sToken },
				body: vBody
			});
		}).then(function (oResponse) {
			if (oResponse.status === 403 && !bRetried && (oResponse.headers.get("X-CSRF-Token") || "").toLowerCase() === "required") {
				sCsrfToken = null;
				return send(sServiceUrl, sMethod, sUrl, vBody, sContentType, true);
			}
			return json(oResponse);
		});
	}

	function entityUrl(sServiceUrl, sSet, sId) {
		return sServiceUrl + sSet + "('" + encodeURIComponent(String(sId).replace(/'/g, "''")) + "')";
	}

	return {
		createDeviceModel: function () {
			var oModel = new JSONModel(Device);
			oModel.setDefaultBindingMode("OneWay");
			return oModel;
		},

		/** View state: side navigation, edit mode, busy flags. */
		createUiModel: function () {
			return new JSONModel({ navKey: "overview", editable: false, busy: false, title: "" });
		},

		createUserModel: function () {
			return new JSONModel({ name: "", displayName: "", initials: "", roles: [], canEdit: false, rights: {}, devUsers: [] });
		},

		/** Signed-in user incl. the effective rights per entity set (/rights/<Set>/read|create|update|remove). */
		loadUser: function (oModel) {
			return fetch(API + "me").then(json).then(function (oUser) {
				var mRights = {};
				((oUser.access && oUser.access.sets) || []).forEach(function (o) { mRights[o.setName] = o; });
				oUser.rights = mRights;
				oUser.unrestricted = !!(oUser.access && oUser.access.unrestricted);
				oUser.devUsers = oUser.devUsers || [];
				oModel.setData(oUser);
			}).catch(function () {
				oModel.setProperty("/displayName", "Unknown user");
				oModel.setProperty("/initials", "?");
			});
		},

		// ---- running comments of an element (REST)

		listComments: function (sSet, sId) {
			return fetch(API + "comments/" + encodeURIComponent(sSet) + "/" + encodeURIComponent(sId)).then(json);
		},

		addComment: function (sServiceUrl, sSet, sId, sText) {
			return modify(sServiceUrl, "POST", API + "comments/" + encodeURIComponent(sSet) + "/" + encodeURIComponent(sId), { text: sText });
		},

		deleteComment: function (sServiceUrl, sCommentId) {
			return modify(sServiceUrl, "DELETE", API + "comments/" + encodeURIComponent(sCommentId));
		},

		// ---- reporting (REST)

		/** Runs a report (sKind "report") or all reports of a report book ("book"); resolves with an array. */
		runReport: function (sKind, sId) {
			var sUrl = API + (sKind === "book" ? "reportbooks/" : "reports/") + encodeURIComponent(sId) + "/run";
			return fetch(sUrl).then(json).then(function (v) { return Array.isArray(v) ? v : [v]; });
		},

		reportExportUrl: function (sKind, sId, sFormat) {
			return API + (sKind === "book" ? "reportbooks/" : "reports/") + encodeURIComponent(sId) + "/export?format=" + sFormat;
		},

		// ---- tenants (Mandanten), backup and restore (REST)

		/** Switches the tenant of all following requests (cookie read by the backend); reload afterwards. */
		switchTenant: function (sTenantId) {
			document.cookie = "eam-tenant=" + encodeURIComponent(sTenantId) + "; path=/; SameSite=Strict";
		},

		listBackups: function () {
			return fetch(API + "backups").then(json);
		},

		createBackup: function (sServiceUrl, sComment) {
			return modify(sServiceUrl, "POST", API + "backups", { comment: sComment || "" });
		},

		deleteBackup: function (sServiceUrl, sId) {
			return modify(sServiceUrl, "DELETE", API + "backups/" + encodeURIComponent(sId));
		},

		backupUrl: function (sId) {
			return API + "backups/" + encodeURIComponent(sId);
		},

		/** Checks (bCheck) or restores a stored backup. Resolves with RestoreResultDto. */
		restoreBackup: function (sServiceUrl, sId, bCheck) {
			return modify(sServiceUrl, "POST", API + "backups/" + encodeURIComponent(sId) + "/restore?check=" + !!bCheck);
		},

		/** Checks or restores an uploaded backup file (stored as backup of kind Upload when restored). */
		restoreUpload: function (sServiceUrl, oFile, bCheck) {
			return oFile.arrayBuffer().then(function (oBuffer) {
				return send(sServiceUrl, "POST", API + "backups/restore?check=" + !!bCheck, oBuffer, "application/octet-stream");
			});
		},

		listTenants: function () {
			return fetch(API + "tenants").then(json);
		},

		createTenant: function (sServiceUrl, oRequest) {
			return modify(sServiceUrl, "POST", API + "tenants", oRequest);
		},

		updateTenant: function (sServiceUrl, sId, oPatch) {
			return modify(sServiceUrl, "PATCH", API + "tenants/" + encodeURIComponent(sId), oPatch);
		},

		deleteTenant: function (sServiceUrl, sId) {
			return modify(sServiceUrl, "DELETE", API + "tenants/" + encodeURIComponent(sId));
		},

		/** Local development only: act as a repository user (cookie read by the backend without XSUAA). */
		actAs: function (sUserName) {
			document.cookie = sUserName
				? "eam-dev-user=" + encodeURIComponent(sUserName) + "; path=/; SameSite=Strict"
				: "eam-dev-user=; path=/; max-age=0; SameSite=Strict";
		},

		createMetaModel: function () {
			return new JSONModel({ sets: [] });
		},

		loadMeta: function (oModel) {
			return fetch(API + "model").then(json).then(function (aSets) {
				oModel.setProperty("/sets", aSets);
			});
		},

		/** id -> name maps and option lists of all sets (for reference fields). */
		createLookupModel: function () {
			var oModel = new JSONModel({});
			oModel.setSizeLimit(5000);
			return oModel;
		},

		/** Loads the names of the sets the user may read (fnCanRead); unreadable references show their id. */
		loadLookup: function (oModel, oMeta, sServiceUrl, fnCanRead) {
			var aSets = (oMeta.getProperty("/sets") || []).filter(function (oSet) { return !fnCanRead || fnCanRead(oSet.name); });
			return Promise.all(aSets.map(function (oSet) {
				return fetch(sServiceUrl + oSet.name + "?$select=id,name&$orderby=name").then(json).then(function (oBody) {
					var mNames = {};
					oBody.value.forEach(function (o) { mNames[o.id] = o.name; });
					oModel.setProperty("/" + oSet.name, mNames);
					oModel.setProperty("/" + oSet.name + "List", oBody.value);
				}).catch(function () { /* no permission (any more): ids are shown */ });
			}));
		},

		/** Portfolio KPIs, TIME assessment, technology risks, product alerts and capability coverage (REST). */
		createPortfolioModel: function () {
			var oModel = new JSONModel({ report: {}, coverage: [], busy: true });
			this.loadPortfolio(oModel);
			return oModel;
		},

		loadPortfolio: function (oModel) {
			oModel.setProperty("/busy", true);
			return Promise.all([
				fetch(API + "analysis/portfolio").then(json),
				fetch(API + "analysis/coverage").then(json)
			]).then(function (aResults) {
				var mCounts = {};
				(aResults[0].counts || []).forEach(function (o) { mCounts[o.kind] = o.count; });
				aResults[0].countByKind = mCounts;
				oModel.setProperty("/report", aResults[0]);
				oModel.setProperty("/coverage", aResults[1]);
			}).catch(function (oError) {
				oModel.setProperty("/error", oError.message);
			}).finally(function () {
				oModel.setProperty("/busy", false);
			});
		},

		// ---- CSV / XLSX import and export (REST)

		/** Download URL of one set (sSet) or of the whole repository (no sSet, XLSX only). */
		exportUrl: function (sSet, sFormat, sSeparator) {
			var sUrl = API + "transfer" + (sSet ? "/" + encodeURIComponent(sSet) : "") + "?format=" + sFormat;
			return sSeparator ? sUrl + "&sep=" + encodeURIComponent(sSeparator) : sUrl;
		},

		/** Uploads a CSV / XLSX file (raw body). Resolves with ImportResultDto (one set) or ImportResultDto[] (all). */
		importFile: function (sServiceUrl, sSet, oFile, bDryRun) {
			var sUrl = API + "transfer" + (sSet ? "/" + encodeURIComponent(sSet) : "") + "?dryRun=" + !!bDryRun;
			var sType = /\.xlsx$/i.test(oFile.name)
				? "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" : "text/csv";
			return oFile.arrayBuffer().then(function (oBuffer) {
				return send(sServiceUrl, "POST", sUrl, oBuffer, sType);
			});
		},

		/** Central search over all entity sets (REST), best hits first. */
		search: function (sQuery, iTop) {
			return fetch(API + "search?q=" + encodeURIComponent(sQuery) + "&top=" + (iTop || 20)).then(json);
		},

		loadImpact: function (sApplicationId) {
			return fetch(API + "analysis/impact/" + encodeURIComponent(sApplicationId)).then(json);
		},

		// ---- OData entity access for the object page (explicit save / cancel instead of $direct field PATCHes)

		readEntity: function (sServiceUrl, sSet, sId) {
			return fetch(entityUrl(sServiceUrl, sSet, sId), { headers: { "Accept": "application/json" } }).then(json);
		},

		createEntity: function (sServiceUrl, sSet, oData) {
			return modify(sServiceUrl, "POST", sServiceUrl + sSet, oData);
		},

		updateEntity: function (sServiceUrl, sSet, sId, oChanges) {
			return modify(sServiceUrl, "PATCH", entityUrl(sServiceUrl, sSet, sId), oChanges);
		},

		deleteEntity: function (sServiceUrl, sSet, sId) {
			return modify(sServiceUrl, "DELETE", entityUrl(sServiceUrl, sSet, sId));
		}
	};
});
