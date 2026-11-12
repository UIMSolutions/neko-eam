sap.ui.define([
	"sap/ui/base/Object",
	"sap/ui/core/Fragment",
	"sap/ui/model/json/JSONModel",
	"sap/m/MessageToast",
	"uim/eam/model/models"
], function (BaseObject, Fragment, JSONModel, MessageToast, models) {
	"use strict";

	/**
	 * CSV / XLSX export (downloads) and the import dialog: choose file → check (dry run, nothing saved)
	 * → import. Used by the list page (one set) and the overview (whole repository workbook).
	 */
	return BaseObject.extend("uim.eam.controller.TransferHelper", {
		constructor: function (oView) {
			BaseObject.call(this);
			this._oView = oView;
			this._oComponent = oView.getController().getOwnerComponent();
			this._oModel = new JSONModel();
		},

		_i18n: function (sKey, aArgs) {
			return this._oComponent.getModel("i18n").getResourceBundle().getText(sKey, aArgs);
		},

		/** Starts a download; the server answers with Content-Disposition: attachment. */
		download: function (sSet, sFormat, sSeparator) {
			var oLink = document.createElement("a");
			oLink.href = models.exportUrl(sSet, sFormat, sSeparator);
			oLink.download = "";
			document.body.appendChild(oLink);
			oLink.click();
			oLink.remove();
		},

		/** Opens the import dialog for one set, or for a workbook with all sets when sSet is empty. */
		openImport: function (sSet, fnImported) {
			this._fnImported = fnImported;
			this._oFile = null;
			this._oModel.setData({
				set: sSet || "",
				title: sSet ? this._i18n("importTitle", [this._i18n("set" + sSet)]) : this._i18n("importAllTitle"),
				fileName: "", step: "select", busy: false, canImport: false,
				status: "", statusType: "None", results: [], issues: []
			});
			if (!this._pDialog) {
				this._pDialog = Fragment.load({ id: this._oView.getId(), name: "uim.eam.view.ImportDialog", controller: this })
					.then(function (oDialog) {
						oDialog.setModel(this._oModel, "import");
						this._oView.addDependent(oDialog);
						return oDialog;
					}.bind(this));
			}
			return this._pDialog.then(function (oDialog) {
				Fragment.byId(this._oView.getId(), "importFile").clear();
				oDialog.open();
				return oDialog;
			}.bind(this));
		},

		onImportFileChange: function (oEvent) {
			var aFiles = oEvent.getParameter("files");
			this._oFile = aFiles && aFiles[0];
			this._oModel.setProperty("/fileName", this._oFile ? this._oFile.name : "");
			this._oModel.setProperty("/step", "select");
			this._oModel.setProperty("/results", []);
			this._oModel.setProperty("/issues", []);
			this._oModel.setProperty("/status", "");
		},

		onImportTypeMismatch: function () {
			this._oModel.setProperty("/status", this._i18n("importWrongType"));
			this._oModel.setProperty("/statusType", "Error");
		},

		onDownloadTemplate: function () {
			this.download(this._oModel.getProperty("/set"), "xlsx");
		},

		/** First press: dry run. Second press (after a successful check): the real import. */
		onImportNext: function () {
			var bDryRun = this._oModel.getProperty("/step") !== "checked";
			var sSet = this._oModel.getProperty("/set");
			this._oModel.setProperty("/busy", true);
			models.importFile(this._oComponent.getServiceUrl(), sSet, this._oFile, bDryRun).then(function (vResult) {
				this._showResults([].concat(vResult), bDryRun);
				if (!bDryRun) {
					MessageToast.show(this._i18n("importDone"));
					this._oComponent.refreshAnalysis();
					if (this._fnImported) { this._fnImported(); }
				}
			}.bind(this)).catch(function (oError) {
				this._oModel.setProperty("/status", oError.message);
				this._oModel.setProperty("/statusType", "Error");
			}.bind(this)).finally(function () {
				this._oModel.setProperty("/busy", false);
			}.bind(this));
		},

		_showResults: function (aResults, bDryRun) {
			var aIssues = [];
			var iChanges = 0, iFailed = 0;
			aResults.forEach(function (oResult) {
				var oInfo = this._oComponent.getSetInfo(oResult.setName);
				oResult.setLabel = oInfo ? this._i18n("set" + oResult.setName) : oResult.setName;
				iChanges += oResult.created + oResult.updated;
				iFailed += oResult.failed;
				oResult.issues.forEach(function (oIssue) {
					var oField = oInfo && oInfo.fields.find(function (f) { return f.name === oIssue.field; });
					oIssue.setLabel = oResult.setLabel;
					oIssue.fieldLabel = oField ? oField.label : oIssue.field;
					aIssues.push(oIssue);
				});
			}, this);
			this._oModel.setProperty("/results", aResults);
			this._oModel.setProperty("/issues", aIssues);
			this._oModel.setProperty("/canImport", iChanges > 0);
			this._oModel.setProperty("/step", bDryRun ? "checked" : "done");
			var sKey = bDryRun ? (iChanges === 0 ? "importNothing" : (iFailed ? "importCheckedWithErrors" : "importChecked")) : "importFinished";
			this._oModel.setProperty("/status", this._i18n(sKey, [iChanges, iFailed]));
			this._oModel.setProperty("/statusType", iFailed ? "Warning" : (bDryRun ? "Information" : "Success"));
		},

		onImportClose: function () {
			this._pDialog.then(function (oDialog) { oDialog.close(); });
		},

		onImportAfterClose: function () {
			this._oFile = null;
		}
	});
});
