/**
 * Start module of the pages outside the app shell (login.html, logout.html): renders the view named by
 * <body data-eam-view="..."> with the app's texts, theme and content density.
 */
sap.ui.define([
	"sap/m/App",
	"sap/ui/core/mvc/XMLView",
	"sap/ui/core/Theming",
	"sap/ui/model/resource/ResourceModel",
	"sap/ui/Device"
], function (App, XMLView, Theming, ResourceModel, Device) {
	"use strict";

	var VIEWS = ["Login", "Logout"];
	var sView = document.body.getAttribute("data-eam-view");
	if (VIEWS.indexOf(sView) < 0) { return; }

	var sTheme = null;
	try { sTheme = window.localStorage.getItem("uim.eam.theme"); } catch (e) { /* storage blocked */ }
	if (sTheme) { Theming.setTheme(sTheme); }

	var oI18n = new ResourceModel({ bundleName: "uim.eam.i18n.i18n", supportedLocales: ["", "de"], fallbackLocale: "" });
	XMLView.create({ viewName: "uim.eam.view." + sView }).then(function (oView) {
		oView.setModel(oI18n, "i18n");
		oView.addStyleClass(Device.support.touch ? "sapUiSizeCozy" : "sapUiSizeCompact");
		document.title = oI18n.getResourceBundle().getText(sView === "Login" ? "loginTitle" : "logoutTitle") + " · Neko EAM";
		// sap.m.App gives the page the full viewport height (like the component container of index.html)
		new App({ pages: [oView] }).placeAt("content");
	});
});
