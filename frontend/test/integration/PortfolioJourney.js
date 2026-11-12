/*global QUnit */
sap.ui.define([
	"sap/ui/test/opaQunit"
], function (opaTest) {
	"use strict";

	QUnit.module("Shell and portfolio");

	opaTest("Shows the Fiori 3 shell bar with the user and the overview", function (Given, When, Then) {
		Given.iStartMyAppInAFrame("../../index.html");
		Then.onTheShell.iSeeTheShellBarWithTheUser();
		Then.onTheOverview.iSeeTheKpiTiles();
	});

	opaTest("Opens the user profile", function (Given, When, Then) {
		When.onTheShell.iPressTheAvatar();
		Then.onTheShell.iSeeTheUserProfile();
	});

	opaTest("Navigates to the products via the sidebar", function (Given, When, Then) {
		When.onTheShell.iSelectTheNavigationItem("Products");
		Then.onTheList.iSeeTheTitle("Products");
		Then.onTheList.iSeeElements();
		Then.onTheShell.iSeeTheNavigationKey("Products");
	});

	opaTest("Offers CSV / Excel export and import on the list", function (Given, When, Then) {
		Then.onTheList.iSeeTheExportMenu();
		When.onTheList.iPressImport();
		Then.onTheList.iSeeTheImportDialog();
	});

	opaTest("Opens a product on the object page", function (Given, When, Then) {
		When.onTheList.iOpenTheFirstElement();
		Then.onTheDetail.iSeeTheObjectPageWithSections(10);
	});

	opaTest("Navigates to the IT landscape planning and opens a measure group", function (Given, When, Then) {
		When.onTheShell.iSelectTheNavigationItem("MeasureGroups");
		Then.onTheList.iSeeTheTitle("Measure Groups");
		Then.onTheList.iSeeElements();
		Then.onTheShell.iSeeTheNavigationKey("MeasureGroups");
		When.onTheList.iOpenTheFirstElement();
		Then.onTheDetail.iSeeTheObjectPageWithSections(4);
	});

	opaTest("Navigates to the specifications and opens a reference architecture", function (Given, When, Then) {
		When.onTheShell.iSelectTheNavigationItem("ReferenceArchitectures");
		Then.onTheList.iSeeTheTitle("Reference Architectures");
		Then.onTheList.iSeeElements();
		When.onTheList.iOpenTheFirstElement();
		Then.onTheDetail.iSeeTheObjectPageWithSections(5);
	});

	opaTest("Navigates to the project management and opens a work package", function (Given, When, Then) {
		When.onTheShell.iSelectTheNavigationItem("WorkPackages");
		Then.onTheList.iSeeTheTitle("Work Packages");
		Then.onTheList.iSeeElements();
		When.onTheList.iOpenTheFirstElement();
		Then.onTheDetail.iSeeTheObjectPageWithSections(4);
	});

	opaTest("Navigates to the access management and opens a role", function (Given, When, Then) {
		When.onTheShell.iSelectTheNavigationItem("Roles");
		Then.onTheList.iSeeTheTitle("Roles");
		Then.onTheList.iSeeElements();
		When.onTheList.iOpenTheFirstElement();
		Then.onTheDetail.iSeeTheObjectPageWithSections(3);
	});

	opaTest("Navigates to the organisation structure and opens a member", function (Given, When, Then) {
		When.onTheShell.iSelectTheNavigationItem("Members");
		Then.onTheList.iSeeTheTitle("Members");
		Then.onTheList.iSeeElements();
		When.onTheList.iOpenTheFirstElement();
		Then.onTheDetail.iSeeTheObjectPageWithSections(3);
	});

	opaTest("Shows backup and restore of the tenant", function (Given, When, Then) {
		When.onTheShell.iSelectTheNavigationItem("backups");
		Then.onTheShell.iSeeTheNavigationKey("backups");
		Then.onTheBackups.iSeeTheBackupPage();
	});

	opaTest("Runs a report from the reporting group", function (Given, When, Then) {
		When.onTheShell.iSelectTheNavigationItem("Reports");
		Then.onTheList.iSeeElements();
		When.onTheList.iOpenTheFirstElement();
		When.onTheDetail.iPressRunReport();
		Then.onTheReport.iSeeReportRows(5);
	});

	opaTest("Shows the running comments of an element", function (Given, When, Then) {
		When.onTheShell.iSelectTheNavigationItem("Applications");
		When.onTheList.iOpenTheFirstElement();
		Then.onTheDetail.iSeeTheCommentInput();
	});

	opaTest("Searches centrally from the shell bar", function (Given, When, Then) {
		When.onTheShell.iSearchFor("customer");
		Then.onTheSearch.iSeeHits(5, "Customer");
		When.onTheSearch.iFilterByType("BusinessCapabilities");
		Then.onTheSearch.iSeeOnlyType("Business Capabilities");
	});

	opaTest("Opens a search hit on the object page", function (Given, When, Then) {
		When.onTheSearch.iOpenTheFirstHit();
		Then.onTheDetail.iSeeTheObjectPageWithSections(2);
		Then.iTeardownMyAppFrame();
	});
});
