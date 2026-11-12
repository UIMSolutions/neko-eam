sap.ui.define([
	"sap/ui/test/Opa5",
	"sap/ui/test/actions/Press",
	"sap/ui/test/matchers/PropertyStrictEquals"
], function (Opa5, Press, PropertyStrictEquals) {
	"use strict";

	Opa5.createPageObjects({
		onTheShell: {
			actions: {
				iSelectTheNavigationItem: function (sKey) {
					return this.waitFor({
						controlType: "sap.tnt.NavigationListItem",
						viewName: "App",
						matchers: new PropertyStrictEquals({ name: "key", value: sKey }),
						actions: new Press(),
						errorMessage: "Navigation item " + sKey + " not found"
					});
				},
				iSearchFor: function (sQuery) {
					return this.waitFor({
						id: "searchManager", viewName: "App", visible: false,
						success: function (oSearchManager) { oSearchManager.fireSearch({ query: sQuery }); },
						errorMessage: "Shell bar search not found"
					});
				},
				iPressTheAvatar: function () {
					return this.waitFor({
						id: "shellBar", viewName: "App",
						success: function (oShellBar) { oShellBar.fireAvatarPressed({ avatar: oShellBar.getProfile() }); },
						errorMessage: "ShellBar not found"
					});
				}
			},
			assertions: {
				iSeeTheShellBarWithTheUser: function () {
					return this.waitFor({
						id: "userAvatar", viewName: "App",
						check: function (oAvatar) { return !!oAvatar.getInitials(); },
						success: function (oAvatar) { Opa5.assert.ok(true, "Avatar shows initials " + oAvatar.getInitials()); },
						errorMessage: "User avatar has no initials"
					});
				},
				iSeeTheUserProfile: function () {
					return this.waitFor({
						id: "userProfilePopover", viewName: "App",
						check: function (oPopover) { return oPopover.isOpen(); },
						success: function () { Opa5.assert.ok(true, "User profile popover is open"); },
						errorMessage: "User profile popover did not open"
					});
				},
				iSeeTheNavigationKey: function (sKey) {
					return this.waitFor({
						id: "sideNavigation", viewName: "App",
						matchers: new PropertyStrictEquals({ name: "selectedKey", value: sKey }),
						success: function () { Opa5.assert.ok(true, "Side navigation selected " + sKey); },
						errorMessage: "Side navigation does not select " + sKey
					});
				}
			}
		},

		onTheBackups: {
			assertions: {
				iSeeTheBackupPage: function () {
					return this.waitFor({
						id: "createBackupButton", viewName: "Backups",
						success: function () { Opa5.assert.ok(true, "Backup page with 'Create Backup' is shown"); },
						errorMessage: "Backup page not shown"
					});
				}
			}
		},
		onTheSearch: {
			actions: {
				iFilterByType: function (sSet) {
					return this.waitFor({
						id: "typeFilter", viewName: "Search",
						check: function (oSelect) { return oSelect.getItems().length > 1; },
						success: function (oSelect) {
							oSelect.setSelectedKey(sSet);
							oSelect.fireChange({ selectedItem: oSelect.getSelectedItem() });
						},
						errorMessage: "Type filter not found"
					});
				},
				iOpenTheFirstHit: function () {
					return this.waitFor({
						id: "resultList", viewName: "Search",
						check: function (oList) { return oList.getItems().length > 0; },
						success: function (oList) { new Press().executeOn(oList.getItems()[0]); },
						errorMessage: "No search hit to open"
					});
				}
			},
			assertions: {
				iSeeHits: function (iMin, sFirstTitle) {
					return this.waitFor({
						id: "resultList", viewName: "Search",
						check: function (oList) {
							var aItems = oList.getItems();
							return aItems.length >= iMin && (!sFirstTitle || aItems[0].getTitle() === sFirstTitle);
						},
						success: function (oList) { Opa5.assert.ok(true, oList.getItems().length + " hits, first: " + oList.getItems()[0].getTitle()); },
						errorMessage: "Expected at least " + iMin + " hits"
					});
				},
				iSeeOnlyType: function (sTypeText) {
					return this.waitFor({
						id: "resultList", viewName: "Search",
						check: function (oList) {
							return oList.getItems().length > 0 && oList.getItems().every(function (o) { return o.getInfo() === sTypeText; });
						},
						success: function () { Opa5.assert.ok(true, "All hits are " + sTypeText); },
						errorMessage: "Type filter not applied"
					});
				}
			}
		},

		onTheOverview: {
			assertions: {
				iSeeTheKpiTiles: function () {
					return this.waitFor({
						id: "productAlertTile", viewName: "Overview",
						success: function () { Opa5.assert.ok(true, "Product alert KPI tile is shown"); },
						errorMessage: "KPI tiles missing"
					});
				}
			}
		},

		onTheList: {
			actions: {
				iPressImport: function () {
					return this.waitFor({
						id: "importButton", viewName: "ElementList",
						actions: new Press(),
						errorMessage: "Import button not found"
					});
				},
				iOpenTheFirstElement: function () {
					return this.waitFor({
						id: "elementTable", viewName: "ElementList",
						check: function (oTable) { return oTable.getItems().length > 0; },
						success: function (oTable) { new Press().executeOn(oTable.getItems()[0]); },
						errorMessage: "No element to open"
					});
				}
			},
			assertions: {
				iSeeElements: function (sTitlePrefix) {
					return this.waitFor({
						id: "elementTable", viewName: "ElementList",
						check: function (oTable) {
							return oTable.getItems().length > 0 && oTable.getColumns().length > 3;
						},
						success: function (oTable) {
							Opa5.assert.ok(true, oTable.getItems().length + " elements with " + oTable.getColumns().length + " columns");
						},
						errorMessage: "List is empty"
					});
				},
				iSeeTheImportDialog: function () {
					return this.waitFor({
						id: "importDialog", viewName: "ElementList",
						check: function (oDialog) { return oDialog.isOpen(); },
						success: function (oDialog) {
							Opa5.assert.ok(true, "Import dialog is open: " + oDialog.getTitle());
							oDialog.close();
						},
						errorMessage: "Import dialog did not open"
					});
				},
				iSeeTheExportMenu: function () {
					return this.waitFor({
						id: "exportButton", viewName: "ElementList",
						check: function (oButton) { return oButton.getMenu().getItems().length === 3; },
						success: function () { Opa5.assert.ok(true, "Export menu offers XLSX and two CSV variants"); },
						errorMessage: "Export menu incomplete"
					});
				},
				iSeeTheTitle: function (sTitle) {
					return this.waitFor({
						id: "listTitle", viewName: "ElementList",
						matchers: new PropertyStrictEquals({ name: "text", value: sTitle }),
						success: function () { Opa5.assert.ok(true, "List title is " + sTitle); },
						errorMessage: "List title is not " + sTitle
					});
				}
			}
		},

		onTheReport: {
			assertions: {
				iSeeReportRows: function (iMin) {
					return this.waitFor({
						controlType: "sap.m.Table", viewName: "ReportResult",
						check: function (aTables) { return aTables.length > 0 && aTables[0].getItems().length >= iMin; },
						success: function (aTables) { Opa5.assert.ok(true, aTables[0].getItems().length + " report rows, " + aTables.length + " table(s)"); },
						errorMessage: "Report result not shown"
					});
				}
			}
		},
		onTheDetail: {
			actions: {
				iPressRunReport: function () {
					return this.waitFor({ id: "runReportButton", viewName: "ElementDetail", actions: new Press(), errorMessage: "No run button" });
				}
			},
			assertions: {
				iSeeTheCommentInput: function () {
					return this.waitFor({
						id: "commentInput", viewName: "ElementDetail",
						success: function () { Opa5.assert.ok(true, "Comment input on the object page"); },
						errorMessage: "No comment input"
					});
				},
				iSeeTheObjectPageWithSections: function (iMin) {
					return this.waitFor({
						id: "objectPage", viewName: "ElementDetail",
						check: function (oPage) { return oPage.getSections().length >= iMin; },
						success: function (oPage) { Opa5.assert.ok(true, oPage.getSections().length + " sections"); },
						errorMessage: "Object page has too few sections"
					});
				}
			}
		}
	});
});
