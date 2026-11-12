/*global QUnit */
sap.ui.define([
	"uim/eam/model/auth"
], function (auth) {
	"use strict";

	QUnit.module("auth");

	QUnit.test("safeTarget keeps app routes and the web cockpit", function (assert) {
		assert.strictEqual(auth.safeTarget("#/sets/Products"), "index.html#/sets/Products");
		assert.strictEqual(auth.safeTarget("/web"), "/web");
		assert.strictEqual(auth.safeTarget("/web/sets/Applications"), "/web/sets/Applications");
		assert.strictEqual(auth.safeTarget("/web/sets/Applications?top=5"), "/web/sets/Applications?top=5");
	});

	QUnit.test("safeTarget rejects other targets (no open redirect)", function (assert) {
		["https://evil.example", "//evil.example", "/\\evil.example", "javascript:alert(1)", "/web//evil.example",
			"/web/../admin", "/webx", "#", "", null, undefined, "#a b"].forEach(function (s) {
			assert.strictEqual(auth.safeTarget(s), "index.html", String(s));
		});
	});

	QUnit.test("loginUrl returns to the current route", function (assert) {
		assert.strictEqual(auth.loginUrl("login.html", "#/sets/Users"), "login.html?returnTo=%23%2Fsets%2FUsers");
		assert.strictEqual(auth.loginUrl("login.html", ""), "login.html");
		assert.strictEqual(auth.loginUrl(null, "#"), "login.html");
	});
});
