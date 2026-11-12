sap.ui.define([
	"sap/ui/core/mvc/Controller",
	"sap/ui/core/routing/History",
	"sap/ui/model/json/JSONModel",
	"sap/ui/model/Filter",
	"sap/ui/model/FilterOperator",
	"sap/ui/layout/form/SimpleForm",
	"sap/uxap/ObjectPageSection",
	"sap/uxap/ObjectPageSubSection",
	"sap/m/Label",
	"sap/m/Text",
	"sap/m/VBox",
	"sap/m/List",
	"sap/m/StandardListItem",
	"sap/m/ObjectStatus",
	"sap/m/ObjectAttribute",
	"sap/m/MessageBox",
	"sap/m/MessageToast",
	"uim/eam/model/models",
	"uim/eam/model/fieldFactory",
	"uim/eam/model/formatter",
	"sap/m/FeedInput",
	"sap/m/FeedListItem",
	"sap/m/FeedListItemAction"
], function (Controller, History, JSONModel, Filter, FilterOperator, SimpleForm, ObjectPageSection, ObjectPageSubSection,
	Label, Text, VBox, List, StandardListItem, ObjectStatus, ObjectAttribute, MessageBox, MessageToast, models, fieldFactory, formatter,
	FeedInput, FeedListItem, FeedListItemAction) {
	"use strict";

	/** Section order; groups not listed here follow in meta model order. */
	var GROUP_ORDER = ["General", "Assessment", "Classification", "Lifecycle", "Reminders", "Licensing",
		"Security & Compliance", "Data Quality", "Usage", "Responsibilities & Support", "Statement", "Planning", "Measurement", "Treatment", "Query", "Progress", "Access", "Legal", "Group Structure", "Contact", "Staffing", "Responsibilities", "Validity", "Release",
		"Services", "Products", "Relations", "Administration"];

	/**
	 * Generic object page for all entity sets. Sections are the field groups of the meta model.
	 * Editing works on a JSON copy of the element; Save sends one PATCH (or POST for new elements).
	 */
	return Controller.extend("uim.eam.controller.ElementDetail", {
		formatter: formatter,

		onInit: function () {
			this.getView().setModel(new JSONModel({}), "obj");
			this.getView().setModel(new JSONModel({ setLabel: "", typeLabel: "", error: "" }), "view");
			this.getOwnerComponent().getRouter().getRoute("detail").attachPatternMatched(this._onRouteMatched, this);
		},

		_i18n: function (sKey, aArgs) {
			return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(sKey, aArgs);
		},

		_ui: function () {
			return this.getOwnerComponent().getModel("ui");
		},

		_onRouteMatched: function (oEvent) {
			var oArgs = oEvent.getParameter("arguments");
			var sSet = oArgs.set;
			var sId = decodeURIComponent(oArgs.id);
			this.getOwnerComponent().whenModelReady().then(function () {
				var oInfo = this.getOwnerComponent().getSetInfo(sSet);
				if (!oInfo) {
					this.getOwnerComponent().getRouter().navTo("overview", {}, true);
					return;
				}
				this.getOwnerComponent().applySetRights(sSet, sId === "new");
				if (this._sSet !== sSet) {
					this._sSet = sSet;
					this._oInfo = oInfo;
					this._buildPage(oInfo);
				}
				var oView = this.getView().getModel("view");
				oView.setProperty("/setLabel", this._i18n("set" + sSet));
				oView.setProperty("/runnable", (sSet === "Reports" || sSet === "ReportBooks") && sId !== "new");
				oView.setProperty("/error", "");
				this._clearValueStates();
				this.byId("objectPage").setSelectedSection(null);
				if (sId === "new") {
					this._sId = null;
					this._ui().setProperty("/isNew", true);
					this._ui().setProperty("/editable", true);
					oView.setProperty("/typeLabel", this._i18n("createTitle", [this._i18n("type" + oInfo.typeName)]));
					this.getView().getModel("obj").setData(fieldFactory.defaults(oInfo));
					this._bindRelated(null);
				} else {
					this._sId = sId;
					this._ui().setProperty("/isNew", false);
					this._ui().setProperty("/editable", false);
					oView.setProperty("/typeLabel", this._i18n("type" + oInfo.typeName) + " · " + sId);
					this._load();
				}
			}.bind(this));
		},

		_load: function () {
			var oComponent = this.getOwnerComponent();
			this._ui().setProperty("/busy", true);
			return models.readEntity(oComponent.getServiceUrl(), this._sSet, this._sId).then(function (oData) {
				delete oData["@odata.context"];
				this._oOriginal = JSON.parse(JSON.stringify(oData));
				this.getView().getModel("obj").setData(oData);
				this._bindRelated(this._sId);
				this._loadComments();
				if (this._sSet === "Applications") { this._loadImpact(); }
			}.bind(this)).catch(function (oError) {
				MessageBox.error(oError.message, { onClose: this.onNavToList.bind(this) });
			}.bind(this)).finally(function () {
				this._ui().setProperty("/busy", false);
			}.bind(this));
		},

		// ------------------------------------------------------------------ page construction

		/** Reports and report books: show the result page. */
		onRunReport: function () {
			this.getOwnerComponent().getRouter().navTo("report", { kind: this._sSet === "Reports" ? "report" : "book", id: encodeURIComponent(this._sId) });
		},

		_buildPage: function (oInfo) {
			var oPage = this.byId("objectPage");
			oPage.destroySections();
			this._mEditors = {};
			this._mSections = {};
			var oRouter = this.getOwnerComponent().getRouter();
			var fnNavigate = function (sSet, sId) {
				oRouter.navTo("detail", { set: sSet, id: encodeURIComponent(sId) });
			};
			var mGroups = {};
			var aOrder = [];
			oInfo.fields.forEach(function (f) {
				if (!mGroups[f.group]) {
					mGroups[f.group] = [];
					aOrder.push(f.group);
				}
				mGroups[f.group].push(f);
			});
			aOrder.sort(function (a, b) {
				var ia = GROUP_ORDER.indexOf(a), ib = GROUP_ORDER.indexOf(b);
				return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib);
			});
			aOrder.forEach(function (sGroup) {
				var oForm = new SimpleForm({
					editable: true,
					layout: "ColumnLayout",
					columnsM: 2, columnsL: 3, columnsXL: 4,
					labelSpanL: 12, labelSpanM: 12
				});
				var oSection = new ObjectPageSection({
					title: this._groupTitle(sGroup),
					titleUppercase: false,
					subSections: [new ObjectPageSubSection({ blocks: [oForm] })]
				});
				mGroups[sGroup].forEach(function (f) {
					oForm.addContent(new Label({ text: f.label, required: f.required, wrapping: true, tooltip: f.name }));
					this._mSections[f.name] = oSection;
					if (f.readOnly) {
						oForm.addContent(fieldFactory.createDisplay(f, "obj", fnNavigate));
						return;
					}
					// display control while viewing, editor while editing (standard Fiori object page behaviour)
					var oDisplay = fieldFactory.createDisplay(f, "obj", fnNavigate);
					oDisplay.bindProperty("visible", { path: "ui>/editable", formatter: function (b) { return !b; } });
					var oEditor = fieldFactory.createEditor(f, "obj");
					oEditor.bindProperty("visible", "ui>/editable");
					this._mEditors[f.name] = oEditor;
					oForm.addContent(oDisplay);
					oForm.addContent(oEditor);
				}.bind(this));
				oPage.addSection(oSection);
			}.bind(this));
			this._addCommentsSection();
			this._addRelatedSection(oInfo);
			if (oInfo.name === "Applications") { this._addImpactSection(); }
			this._buildHeaderFacets(oInfo);
		},

		_groupTitle: function (sGroup) {
			var sKey = "group" + sGroup.replace(/[^A-Za-z]/g, "");
			var sText = this._i18n(sKey);
			return sText === sKey ? sGroup : sText;
		},

		/** Header: enumeration list columns as status facets plus the last update info. */
		_buildHeaderFacets: function (oInfo) {
			var oBox = this.byId("headerFacets");
			oBox.destroyItems();
			oInfo.fields.filter(function (f) { return f.choices.length && f.listColumn; }).slice(0, 4).forEach(function (f) {
				oBox.addItem(new VBox({
					items: [
						new Label({ text: f.label }),
						new ObjectStatus({ text: "{obj>/" + f.name + "}", state: { path: "obj>/" + f.name, formatter: formatter.valueState }, inverted: true })
					]
				}).addStyleClass("sapUiMediumMarginEnd sapUiSmallMarginBottom"));
			});
			oBox.addItem(new VBox({
				visible: "{= !${ui>/isNew} }",
				items: [
					new ObjectAttribute({ title: this._i18n("lastUpdate"), text: { path: "obj>/modifiedAt", formatter: formatter.timestamp } }),
					new ObjectAttribute({ title: this._i18n("lastUpdateUser"), text: "{obj>/modifiedBy}" })
				]
			}).addStyleClass("sapUiMediumMarginEnd"));
		},

		/** Running comments (journal): newest first, date and author recorded automatically, own entries deletable. */
		_addCommentsSection: function () {
			this.getView().setModel(new JSONModel({ comments: [], count: 0 }), "comments");
			var oInput = new FeedInput({
				id: this.createId("commentInput"),
				placeholder: this._i18n("commentPlaceholder"),
				showIcon: true,
				icon: "sap-icon://comment",
				rows: 3,
				growing: true,
				maxLength: 4000,
				post: this.onPostComment.bind(this)
			});
			var oList = new List({
				id: this.createId("commentList"),
				showSeparators: "Inner",
				noDataText: this._i18n("commentsNone"),
				growing: true,
				growingThreshold: 20,
				items: {
					path: "comments>/comments",
					templateShareable: false,
					template: new FeedListItem({
						sender: "{comments>createdBy}",
						text: "{comments>text}",
						timestamp: { path: "comments>createdAt", formatter: formatter.timestamp },
						icon: "sap-icon://comment",
						showIcon: false,
						convertLinksToAnchorTags: "All",
						actions: [new FeedListItemAction({
							text: this._i18n("delete"), icon: "sap-icon://delete", key: "delete",
							visible: "{comments>deletable}",
							press: this.onDeleteComment.bind(this)
						})]
					})
				}
			});
			this.byId("objectPage").addSection(new ObjectPageSection({
				id: this.createId("commentsSection"),
				title: { path: "comments>/count", formatter: function (n) { return this._i18n("sectionComments", [n || 0]); }.bind(this) },
				titleUppercase: false,
				visible: "{= !${ui>/isNew} }",
				subSections: [new ObjectPageSubSection({ blocks: [new VBox({ items: [oInput, oList] })] })]
			}));
		},

		_loadComments: function () {
			var oModel = this.getView().getModel("comments");
			if (!oModel || !this._sId) { return; }
			models.listComments(this._sSet, this._sId).then(function (aComments) {
				oModel.setData({ comments: aComments, count: aComments.length });
			}).catch(function () {
				oModel.setData({ comments: [], count: 0 });
			});
		},

		onPostComment: function (oEvent) {
			var sText = oEvent.getParameter("value");
			models.addComment(this.getOwnerComponent().getServiceUrl(), this._sSet, this._sId, sText).then(function () {
				MessageToast.show(this._i18n("commentAdded"));
				this._loadComments();
			}.bind(this)).catch(function (oError) {
				MessageBox.error(oError.message);
			});
		},

		onDeleteComment: function (oEvent) {
			var oComment = oEvent.getSource().getBindingContext("comments").getObject();
			MessageBox.confirm(this._i18n("commentDeleteConfirm"), {
				onClose: function (sAction) {
					if (sAction !== MessageBox.Action.OK) { return; }
					models.deleteComment(this.getOwnerComponent().getServiceUrl(), oComment.id)
						.then(this._loadComments.bind(this))
						.catch(function (oError) { MessageBox.error(oError.message); });
				}.bind(this)
			});
		},

		/** "Where used": elements of other sets referencing this element (single and collection references). */
		_addRelatedSection: function (oInfo) {
			var aRefs = [];
			(this.getOwnerComponent().getModel("meta").getProperty("/sets") || []).forEach(function (oSet) {
				oSet.fields.forEach(function (f) {
					if (f.reference === oInfo.name) { aRefs.push({ set: oSet, field: f }); }
				});
			});
			if (!aRefs.length) { return; }
			this._aRelatedLists = [];
			var aSubSections = aRefs.map(function (oRef) {
				var oList = new List({ noDataText: this._i18n("noReferences"), growing: true, growingThreshold: 10 });
				oList.data("ref", oRef);
				this._aRelatedLists.push(oList);
				return new ObjectPageSubSection({
					title: this._i18n("set" + oRef.set.name) + " – " + oRef.field.label,
					titleUppercase: false,
					blocks: [oList]
				});
			}.bind(this));
			this.byId("objectPage").addSection(new ObjectPageSection({
				title: this._i18n("sectionWhereUsed"),
				titleUppercase: false,
				visible: "{= !${ui>/isNew} }",
				subSections: aSubSections
			}));
		},

		_bindRelated: function (sId) {
			(this._aRelatedLists || []).forEach(function (oList) {
				var oRef = oList.data("ref");
				if (!sId) { oList.unbindItems(); return; }
				var oFilter = oRef.field.type === "StringCollection"
					? new Filter({ path: oRef.field.name, operator: FilterOperator.Any, variable: "r",
						condition: new Filter("r", FilterOperator.EQ, sId) })
					: new Filter(oRef.field.name, FilterOperator.EQ, sId);
				oList.bindItems({
					path: "/" + oRef.set.name,
					parameters: { $select: "id,name" },
					filters: [oFilter],
					templateShareable: false,
					template: new StandardListItem({
						title: "{name}", description: "{id}", type: "Navigation",
						press: function (oEvent) {
							var sTarget = oEvent.getSource().getBindingContext().getProperty("id");
							this.getOwnerComponent().getRouter().navTo("detail", { set: oRef.set.name, id: encodeURIComponent(sTarget) });
						}.bind(this)
					})
				});
			}.bind(this));
		},

		_addImpactSection: function () {
			this.getView().setModel(new JSONModel({}), "impact");
			var oBox = new VBox({ items: [
				new ObjectAttribute({ title: this._i18n("impactProviders"), text: { parts: ["impact>/providingApplicationIds", "lookup>/Applications"], formatter: formatter.refNames } }),
				new ObjectAttribute({ title: this._i18n("impactConsumers"), text: { parts: ["impact>/dependentApplicationIds", "lookup>/Applications"], formatter: formatter.refNames } }),
				new ObjectAttribute({ title: this._i18n("impactIncoming"), text: { parts: ["impact>/incomingFlowIds", "lookup>/InformationFlows"], formatter: formatter.refNames } }),
				new ObjectAttribute({ title: this._i18n("impactOutgoing"), text: { parts: ["impact>/outgoingFlowIds", "lookup>/InformationFlows"], formatter: formatter.refNames } }),
				new ObjectAttribute({ title: this._i18n("impactProjects"), text: { parts: ["impact>/projectIds", "lookup>/Projects"], formatter: formatter.refNames } })
			] });
			this.byId("objectPage").addSection(new ObjectPageSection({
				title: this._i18n("sectionImpact"),
				titleUppercase: false,
				visible: "{= !${ui>/isNew} }",
				subSections: [new ObjectPageSubSection({ blocks: [oBox] })]
			}));
		},

		_loadImpact: function () {
			models.loadImpact(this._sId).then(function (oImpact) {
				this.getView().getModel("impact").setData(oImpact);
			}.bind(this)).catch(function () {
				this.getView().getModel("impact").setData({});
			}.bind(this));
		},

		// ------------------------------------------------------------------ actions

		onEdit: function () {
			this._ui().setProperty("/editable", true);
		},

		onCancel: function () {
			this._clearValueStates();
			this.getView().getModel("view").setProperty("/error", "");
			if (this._ui().getProperty("/isNew")) {
				this._ui().setProperty("/editable", false);
				this.onNavToList();
				return;
			}
			this.getView().getModel("obj").setData(JSON.parse(JSON.stringify(this._oOriginal)));
			this._ui().setProperty("/editable", false);
		},

		onSave: function () {
			var oComponent = this.getOwnerComponent();
			var oData = fieldFactory.normalize(this._oInfo, this.getView().getModel("obj").getData());
			var bNew = this._ui().getProperty("/isNew");
			var pRequest;
			if (bNew) {
				if (!oData.id) { delete oData.id; }
				pRequest = models.createEntity(oComponent.getServiceUrl(), this._sSet, oData);
			} else {
				var oChanges = {};
				var oOriginal = fieldFactory.normalize(this._oInfo, this._oOriginal);
				Object.keys(oData).forEach(function (k) {
					if (k !== "id" && JSON.stringify(oData[k]) !== JSON.stringify(oOriginal[k])) { oChanges[k] = oData[k]; }
				});
				if (!Object.keys(oChanges).length) {
					this._ui().setProperty("/editable", false);
					return;
				}
				pRequest = models.updateEntity(oComponent.getServiceUrl(), this._sSet, this._sId, oChanges);
			}
			this._clearValueStates();
			this._ui().setProperty("/busy", true);
			pRequest.then(function (oSaved) {
				this.getView().getModel("view").setProperty("/error", "");
				this._ui().setProperty("/editable", false);
				MessageToast.show(this._i18n(bNew ? "created" : "saved"));
				oComponent.getModel().refresh();
				oComponent.refreshAnalysis();
				if (bNew) {
					oComponent.getRouter().navTo("detail", { set: this._sSet, id: encodeURIComponent(oSaved.id) }, true);
				} else {
					delete oSaved["@odata.context"];
					this._oOriginal = JSON.parse(JSON.stringify(oSaved));
					this.getView().getModel("obj").setData(oSaved);
					this._bindRelated(this._sId);
				}
			}.bind(this)).catch(function (oError) {
				this._showError(oError);
			}.bind(this)).finally(function () {
				this._ui().setProperty("/busy", false);
			}.bind(this));
		},

		_showError: function (oError) {
			var oView = this.getView().getModel("view");
			oView.setProperty("/error", oError.message);
			oView.setProperty("/errorCount", "1");
			var oEditor = oError.target && this._mEditors[oError.target];
			if (oEditor && oEditor.setValueState) {
				oEditor.setValueState("Error");
				oEditor.setValueStateText(oError.message);
				this.byId("objectPage").scrollToSection(this._mSections[oError.target].getId());
			}
			MessageBox.error(oError.message);
		},

		onShowError: function () {
			MessageBox.error(this.getView().getModel("view").getProperty("/error"));
		},

		_clearValueStates: function () {
			Object.values(this._mEditors || {}).forEach(function (o) {
				if (o.setValueState) { o.setValueState("None"); }
			});
		},

		onDelete: function () {
			var oComponent = this.getOwnerComponent();
			MessageBox.confirm(this._i18n("deleteConfirmNamed", [this.getView().getModel("obj").getProperty("/name")]), {
				onClose: function (sAction) {
					if (sAction !== MessageBox.Action.OK) { return; }
					models.deleteEntity(oComponent.getServiceUrl(), this._sSet, this._sId).then(function () {
						MessageToast.show(this._i18n("deleted"));
						oComponent.getModel().refresh();
						oComponent.refreshAnalysis();
						this.onNavToList();
					}.bind(this)).catch(function (oError) {
						MessageBox.error(oError.message);
					});
				}.bind(this)
			});
		},

		onNavToList: function () {
			this._ui().setProperty("/editable", false);
			this.getOwnerComponent().getRouter().navTo("list", { set: this._sSet });
		},

		onClose: function () {
			if (this._ui().getProperty("/editable")) {
				this.onCancel();
				if (this._ui().getProperty("/isNew")) { return; }
			}
			if (History.getInstance().getPreviousHash() !== undefined) {
				window.history.go(-1);
			} else {
				this.onNavToList();
			}
		}
	});
});
