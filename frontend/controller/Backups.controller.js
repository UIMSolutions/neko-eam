sap.ui.define([
	"sap/ui/core/mvc/Controller",
	"sap/ui/model/json/JSONModel",
	"sap/m/MessageBox",
	"sap/m/MessageToast",
	"sap/m/Dialog",
	"sap/m/Button",
	"sap/m/Label",
	"sap/m/TextArea",
	"sap/m/MessageStrip",
	"sap/m/VBox",
	"sap/ui/unified/FileUploader",
	"sap/ui/core/format/DateFormat",
	"uim/eam/model/models"
], function (Controller, JSONModel, MessageBox, MessageToast, Dialog, Button, Label, TextArea, MessageStrip, VBox,
		FileUploader, DateFormat, models) {
	"use strict";

	var oDateFormat = DateFormat.getDateTimeInstance({ style: "medium" });

	/** Backup and restore of the current tenant (tenant administrators and system administrators). */
	return Controller.extend("uim.eam.controller.Backups", {
		onInit: function () {
			this.getView().setModel(new JSONModel({ backups: [], busy: false, noData: "" }), "view");
			this.getOwnerComponent().getRouter().getRoute("backups").attachPatternMatched(this.onRefresh, this);
		},

		_i18n: function (sKey, aArgs) {
			return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(sKey, aArgs);
		},

		_url: function () {
			return this.getOwnerComponent().getServiceUrl();
		},

		formatDate: function (s) {
			return s ? oDateFormat.format(new Date(s)) : "";
		},

		formatSize: function (n) {
			if (!n) { return ""; }
			return n < 1024 * 1024 ? (n / 1024).toFixed(1) + " KB" : (n / 1024 / 1024).toFixed(1) + " MB";
		},

		kindText: function (s) {
			return s ? this._i18n("backupKind" + s) : "";
		},

		onRefresh: function () {
			var oView = this.getView().getModel("view");
			oView.setProperty("/busy", true);
			return models.listBackups().then(function (aBackups) {
				oView.setProperty("/backups", aBackups);
				oView.setProperty("/noData", this._i18n("backupsNone"));
			}.bind(this)).catch(function (oError) {
				oView.setProperty("/backups", []);
				oView.setProperty("/noData", oError.message);
			}).finally(function () {
				oView.setProperty("/busy", false);
			});
		},

		_row: function (oEvent) {
			return oEvent.getSource().getBindingContext("view").getObject();
		},

		onCreate: function () {
			var oComment = new TextArea({ width: "100%", rows: 3, placeholder: this._i18n("backupCommentPlaceholder") });
			var oDialog = new Dialog({
				title: this._i18n("backupCreate"),
				contentWidth: "28rem",
				content: [new VBox({ items: [new Label({ text: this._i18n("backupComment"), labelFor: oComment }), oComment] }).addStyleClass("sapUiSmallMargin")],
				beginButton: new Button({
					text: this._i18n("backupCreate"), type: "Emphasized",
					press: function () {
						oDialog.setBusy(true);
						models.createBackup(this._url(), oComment.getValue()).then(function (oInfo) {
							MessageToast.show(this._i18n("backupCreated", [oInfo.elements]));
							oDialog.close();
							this.onRefresh();
						}.bind(this)).catch(function (oError) {
							MessageBox.error(oError.message);
						}).finally(function () { oDialog.setBusy(false); });
					}.bind(this)
				}),
				endButton: new Button({ text: this._i18n("cancel"), press: function () { oDialog.close(); } }),
				afterClose: function () { oDialog.destroy(); }
			});
			this.getView().addDependent(oDialog);
			oDialog.open();
		},

		onDownload: function (oEvent) {
			window.location.href = models.backupUrl(this._row(oEvent).id);
		},

		onCheck: function (oEvent) {
			models.restoreBackup(this._url(), this._row(oEvent).id, true).then(function (oResult) {
				MessageBox.success(this._resultText(oResult, true));
			}.bind(this)).catch(function (oError) { MessageBox.error(oError.message); });
		},

		/** Check first, then ask - the confirmation shows what will be restored and that a safety backup is taken. */
		onRestore: function (oEvent) {
			var oBackup = this._row(oEvent);
			models.restoreBackup(this._url(), oBackup.id, true).then(function (oCheck) {
				MessageBox.warning(this._resultText(oCheck, true) + "\n\n" + this._i18n("backupRestoreConfirm"), {
					actions: [this._i18n("backupRestore"), MessageBox.Action.CANCEL],
					emphasizedAction: this._i18n("backupRestore"),
					onClose: function (sAction) {
						if (sAction !== this._i18n("backupRestore")) { return; }
						models.restoreBackup(this._url(), oBackup.id, false).then(this._restored.bind(this))
							.catch(function (oError) { MessageBox.error(oError.message); });
					}.bind(this)
				});
			}.bind(this)).catch(function (oError) { MessageBox.error(oError.message); });
		},

		onDelete: function (oEvent) {
			var oBackup = this._row(oEvent);
			MessageBox.confirm(this._i18n("backupDeleteConfirm", [this.formatDate(oBackup.createdAt)]), {
				onClose: function (sAction) {
					if (sAction !== MessageBox.Action.OK) { return; }
					models.deleteBackup(this._url(), oBackup.id).then(this.onRefresh.bind(this))
						.catch(function (oError) { MessageBox.error(oError.message); });
				}.bind(this)
			});
		},

		/** Upload a backup file: check, confirm, restore (the file is kept as backup of kind Upload). */
		onUpload: function () {
			var oFile = null;
			var oStrip = new MessageStrip({ text: this._i18n("backupUploadHelp"), type: "Information", showIcon: true });
			var oUploader = new FileUploader({
				width: "100%", fileType: ["eambackup", "gz", "json"], placeholder: this._i18n("backupUploadPlaceholder"),
				change: function (oChange) { oFile = oChange.getParameter("files") && oChange.getParameter("files")[0]; }
			});
			var oDialog = new Dialog({
				title: this._i18n("backupUpload"),
				contentWidth: "32rem",
				content: [new VBox({ items: [oStrip, oUploader] }).addStyleClass("sapUiSmallMargin")],
				beginButton: new Button({
					text: this._i18n("backupCheckAndRestore"), type: "Emphasized",
					press: function () {
						if (!oFile) { return; }
						oDialog.setBusy(true);
						models.restoreUpload(this._url(), oFile, true).then(function (oCheck) {
							oDialog.setBusy(false);
							MessageBox.warning(this._resultText(oCheck, true) + "\n\n" + this._i18n("backupRestoreConfirm"), {
								actions: [this._i18n("backupRestore"), MessageBox.Action.CANCEL],
								emphasizedAction: this._i18n("backupRestore"),
								onClose: function (sAction) {
									if (sAction !== this._i18n("backupRestore")) { return; }
									models.restoreUpload(this._url(), oFile, false).then(function (oResult) {
										oDialog.close();
										this._restored(oResult);
									}.bind(this)).catch(function (oError) { MessageBox.error(oError.message); });
								}.bind(this)
							});
						}.bind(this)).catch(function (oError) {
							oDialog.setBusy(false);
							MessageBox.error(oError.message);
						});
					}.bind(this)
				}),
				endButton: new Button({ text: this._i18n("cancel"), press: function () { oDialog.close(); } }),
				afterClose: function () { oDialog.destroy(); }
			});
			this.getView().addDependent(oDialog);
			oDialog.open();
		},

		_resultText: function (oResult, bCheck) {
			var aLines = [this._i18n(bCheck ? "backupCheckOk" : "backupRestored",
				[oResult.sourceTenant, this.formatDate(oResult.backupCreatedAt), oResult.elements])];
			(oResult.warnings || []).forEach(function (s) { aLines.push("⚠ " + s); });
			return aLines.join("\n");
		},

		/** The data of the whole tenant changed: reload the app (lookups, rights, analysis). */
		_restored: function (oResult) {
			MessageBox.success(this._resultText(oResult, false) + "\n\n" + this._i18n("backupSafety", [oResult.safetyBackupId]), {
				onClose: function () { window.location.reload(); }
			});
		}
	});
});
