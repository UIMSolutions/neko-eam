/// Type-safe configuration: defaults <- config/default.json <- environment variables <- VCAP_SERVICES.
module neko.eam.infrastructure.configuration;

import std.conv : to;
import std.file : exists, readText;
import std.process : environment;
import vibe.data.json;

struct XsuaaConfig {
	string xsappname = "neko-eam";
	string clientid;
	string url;
	string verificationkey; /// PEM public key used to verify RS256 tokens
}

struct AppConfig {
	string bindAddress = "127.0.0.1";
	ushort port = 8080;
	string logLevel = "info";
	string dataFile = "data/eam.json";
	bool seedOnEmpty = true;
	string tenantRegistryFile = "data/tenants.json"; /// tenants (Mandanten); the default tenant uses `dataFile`
	string tenantDirectory = "data/tenants";          /// data files of the other tenants (<id>.json)
	string backupDirectory = "data/backups";          /// backups (<tenant>/<id>.eambackup)
	uint backupRetention = 10;                        /// scheduled backups kept per tenant
	uint backupIntervalHours = 24;                    /// scheduled backups of all tenants (0 = off)
	string frontendPath = "../frontend";
	string odataBasePath = "/odata/v4/eam";
	string authMode = "none"; /// none | xsuaa
	XsuaaConfig xsuaa;
	string tlsCertificateFile;
	string tlsPrivateKeyFile;
	uint healthCheckIntervalSeconds = 300;
	string webviewUrl;
	string configFile; /// file the configuration was loaded from (informational)
}

/// Loads the configuration with the documented precedence.
AppConfig loadConfiguration(string file = null) {
	AppConfig cfg;
	if (file is null) file = environment.get("EAM_CONFIG", "config/default.json");
	if (exists(file)) {
		applyJson(cfg, parseJsonString(readText(file)));
		cfg.configFile = file;
	}
	applyEnvironment(cfg, environment.toAA());
	return cfg;
}

/// Applies a JSON object onto the configuration (only present keys).
void applyJson(ref AppConfig cfg, Json j) {
	static foreach (name; __traits(allMembers, AppConfig)) {
		static if (name != "xsuaa" && name != "configFile") {
			if (j[name].type != Json.Type.undefined)
				__traits(getMember, cfg, name) = j[name].to!string.to!(typeof(__traits(getMember, cfg, name)));
		}
	}
	if (j["xsuaa"].type == Json.Type.object)
		applyXsuaa(cfg.xsuaa, j["xsuaa"]);
}

private void applyXsuaa(ref XsuaaConfig x, Json j) {
	static foreach (name; __traits(allMembers, XsuaaConfig))
		if (j[name].type == Json.Type.string) __traits(getMember, x, name) = j[name].get!string;
}

/// Environment variables (EAM_*), Cloud Foundry PORT and VCAP_SERVICES (highest priority).
void applyEnvironment(ref AppConfig cfg, string[string] env) {
	if (auto v = "EAM_BIND_ADDRESS" in env) cfg.bindAddress = *v;
	if (auto v = "EAM_PORT" in env) cfg.port = (*v).to!ushort;
	if (auto v = "EAM_LOG_LEVEL" in env) cfg.logLevel = *v;
	if (auto v = "EAM_DATA_FILE" in env) cfg.dataFile = *v;
	if (auto v = "EAM_SEED_ON_EMPTY" in env) cfg.seedOnEmpty = (*v).to!bool;
	if (auto v = "EAM_FRONTEND_PATH" in env) cfg.frontendPath = *v;
	if (auto v = "EAM_AUTH_MODE" in env) cfg.authMode = *v;
	if (auto v = "EAM_TLS_CERT" in env) cfg.tlsCertificateFile = *v;
	if (auto v = "EAM_TLS_KEY" in env) cfg.tlsPrivateKeyFile = *v;
	if (auto v = "EAM_WEBVIEW_URL" in env) cfg.webviewUrl = *v;
	if (auto v = "EAM_TENANT_REGISTRY" in env) cfg.tenantRegistryFile = *v;
	if (auto v = "EAM_TENANT_DIR" in env) cfg.tenantDirectory = *v;
	if (auto v = "EAM_BACKUP_DIR" in env) cfg.backupDirectory = *v;
	if (auto v = "EAM_BACKUP_RETENTION" in env) cfg.backupRetention = (*v).to!uint;
	if (auto v = "EAM_BACKUP_INTERVAL_HOURS" in env) cfg.backupIntervalHours = (*v).to!uint;
	if (auto v = "PORT" in env) { // Cloud Foundry assigns the port and expects 0.0.0.0
		cfg.port = (*v).to!ushort;
		cfg.bindAddress = "0.0.0.0";
	}
	if (auto v = "VCAP_SERVICES" in env) {
		auto vcap = parseJsonString(*v);
		if (vcap["xsuaa"].type == Json.Type.array && vcap["xsuaa"].length > 0) {
			applyXsuaa(cfg.xsuaa, vcap["xsuaa"][0]["credentials"]);
			cfg.authMode = "xsuaa";
		}
	}
}

unittest {
	AppConfig cfg;
	applyJson(cfg, parseJsonString(`{"port": 9000, "seedOnEmpty": false, "xsuaa": {"xsappname": "x"}}`));
	assert(cfg.port == 9000 && !cfg.seedOnEmpty && cfg.xsuaa.xsappname == "x");
	applyEnvironment(cfg, ["EAM_PORT": "9100", "VCAP_SERVICES":
		`{"xsuaa":[{"credentials":{"xsappname":"eam!t1","clientid":"sb-eam"}}]}`]);
	assert(cfg.port == 9100 && cfg.authMode == "xsuaa" && cfg.xsuaa.clientid == "sb-eam");
	applyEnvironment(cfg, ["PORT": "8443"]);
	assert(cfg.port == 8443 && cfg.bindAddress == "0.0.0.0");
}
