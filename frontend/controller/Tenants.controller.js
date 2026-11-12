sap.ui.define([
	"sap/ui/core/mvc/Controller",
	"sap/ui/model/json/JSONModel",
	"sap/m/MessageBox",
	"sap/m/MessageToast",
	"sap/m/Dialog",
	"sap/m/Button",
	"sap/m/Label",
	"sap/m/Input",
	"sap/m/TextArea",
	"sap/m/CheckBox",
	"sap/m/Select",
	"sap/ui/core/Item",
	"sap/ui/layout/form/SimpleForm",
	"uim/eam/model/models"
], function (Controller, JSONModel, MessageBox, MessageToast, Dialog, Button, Label, Input, TextArea, CheckBox, Select,
		Item, SimpleForm, models) {
	"use strict";

	/** Tenant (Mandant) administration - system administrators only. */
	return Controller.extend("uim.eam.controller.Tenants", {
		onInit: function () {
			this.getView().setModel(new JSONModel({ tenants: [], busy: false, noData: "" }), "view");
			this.getOwnerComponent().getRouter().getRoute("tenants").attachPatternMatched(this.onRefresh, this);
		},

		_i18n: function (sKey, aArgs) {
			return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(sKey, aArgs);
		},

		_url: function () {
			return this.getOwnerComponent().getServiceUrl();
		},

		/** Last two path segments ("tenants/acme.json") - the full path is the tooltip. */
		shortPath: function (s) {
			return (s || "").split("/").slice(-2).join("/");
		},

		onRefresh: function () {
			var oView = this.getView().getModel("view");
			oView.setProperty("/busy", true);
			return models.listTenants().then(function (aTenants) {
				oView.setProperty("/tenants", aTenants);
			}).catch(function (oError) {
				oView.setProperty("/tenants", []);
				oView.setProperty("/noData", oError.message);
			}).finally(function () {
				oView.setProperty("/busy", false);
			});
		},

		_row: function (oEvent) {
			return oEvent.getSource().getBindingContext("view").getObject();
		},

		onCreate: function () {
			this._openDialog(null);
		},

		onEdit: function (oEvent) {
			this._openDialog(this._row(oEvent));
		},

		onSwitch: function (oEvent) {
			models.switchTenant(this._row(oEvent).id);
			window.location.hash = "";
			window.location.reload();
		},

		onDelete: function (oEvent) {
			var oTenant = this._row(oEvent);
			MessageBox.warning(this._i18n("tenantDeleteConfirm", [oTenant.name, oTenant.id]), {
				actions: [this._i18n("delete"), MessageBox.Action.CANCEL],
				emphasizedAction: MessageBox.Action.CANCEL,
				onClose: function (sAction) {
					if (sAction !== this._i18n("delete")) { return; }
					models.deleteTenant(this._url(), oTenant.id).then(function () {
						MessageToast.show(this._i18n("tenantDeleted", [oTenant.id]));
						this.onRefresh();
					}.bind(this)).catch(function (oError) { MessageBox.error(oError.message); });
				}.bind(this)
			});
		},

		/** Create (oTenant null) or edit dialog. */
		_openDialog: function (oTenant) {
			var bNew = !oTenant;
			var oData = new JSONModel(bNew
				? { id: "", name: "", description: "", zoneId: "", status: "Active", seedDemoData: false, adminUserName: "", adminEmail: "" }
				: Object.assign({}, oTenant));
			var oForm = new SimpleForm({
				editable: true, layout: "ResponsiveGridLayout", labelSpanM: 4, labelSpanL: 4,
				content: [
					new Label({ text: this._i18n("tenantId"), required: true }),
					new Input({ value: "{d>/id}", editable: bNew, placeholder: "acme" }),
					new Label({ text: this._i18n("tenantName"), required: true }),
					new Input({ value: "{d>/name}" }),
					new Label({ text: this._i18n("tenantDescription") }),
					new TextArea({ value: "{d>/description}", rows: 2 }),
					new Label({ text: this._i18n("tenantZone") }),
					new Input({ value: "{d>/zoneId}", placeholder: this._i18n("tenantZoneHint") }),
					new Label({ text: this._i18n("tenantStatus") }),
					new Select({ selectedKey: "{d>/status}", enabled: bNew ? false : "{= ${d>/id} !== 'default' }",
						items: [new Item({ key: "Active", text: "Active" }), new Item({ key: "Suspended", text: "Suspended" })] })
				]
			});
			if (bNew) {
				oForm.addContent(new Label({ text: this._i18n("tenantAdminUser") }));
				oForm.addContent(new Input({ value: "{d>/adminUserName}", placeholder: this._i18n("tenantAdminUserHint") }));
				oForm.addContent(new Label({ text: this._i18n("tenantAdminEmail") }));
				oForm.addContent(new Input({ value: "{d>/adminEmail}", type: "Email" }));
				oForm.addContent(new Label({ text: this._i18n("tenantSeed") }));
				oForm.addContent(new CheckBox({ selected: "{d>/seedDemoData}" }));
			}
			var oDialog = new Dialog({
				title: this._i18n(bNew ? "tenantCreate" : "tenantEdit"),
				contentWidth: "34rem",
				content: [oForm],
				beginButton: new Button({
					text: this._i18n(bNew ? "create" : "save"), type: "Emphasized",
					press: function () {
						var d = oData.getData();
						var pSave = bNew
							? models.createTenant(this._url(), {
								tenant: { id: d.id, name: d.name, description: d.description, zoneId: d.zoneId },
								seedDemoData: d.seedDemoData, adminUserName: d.adminUserName, adminEmail: d.adminEmail })
							: models.updateTenant(this._url(), d.id, { name: d.name, description: d.description, zoneId: d.zoneId, status: d.status });
						oDialog.setBusy(true);
						pSave.then(function () {
							oDialog.close();
							this.onRefresh();
							this.getOwnerComponent().reloadUser();
						}.bind(this)).catch(function (oError) {
							MessageBox.error(oError.message);
						}).finally(function () { oDialog.setBusy(false); });
					}.bind(this)
				}),
				endButton: new Button({ text: this._i18n("cancel"), press: function () { oDialog.close(); } }),
				afterClose: function () { oDialog.destroy(); }
			});
			oDialog.setModel(oData, "d");
			this.getView().addDependent(oDialog);
			oDialog.open();
		}
	});
});
