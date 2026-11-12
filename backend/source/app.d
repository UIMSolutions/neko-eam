/// Entry point: `eam serve | gui | webview | <cli command>`.
module app;

import core.thread : Thread;
import core.time : msecs, seconds;
import std.algorithm : countUntil;
import std.conv : to;
import std.socket : TcpSocket, InternetAddress;
import std.stdio : stderr, writeln;
import vibe.core.core : runEventLoop;

import neko.eam.composition;
import neko.eam.infrastructure;
import neko.eam.presentation;

int main(string[] args) {
	auto mode = args.length > 1 ? args[1] : "serve";
	AppConfig cfg;
	try cfg = loadConfiguration();
	catch (Exception e) { stderr.writeln("Invalid configuration: ", e.msg); return 2; }
	if (auto p = option(args, "--port")) cfg.port = p.to!ushort;

	try switch (mode) {
		case "serve":
			configureLogging(cfg.logLevel);
			auto platform = EamContainer.platformFromConfig(cfg);
			startHttpServer(cfg, platform, new Authenticator(cfg));
			startArchitectureHealthWorker(platform.tenantUseCases("default").analysis, cfg.healthCheckIntervalSeconds);
			startBackupWorker(platform, cfg.backupIntervalHours);
			return runEventLoop();

		case "gui":
			static if (guiAvailable) {
				configureLogging("warn");
				return runDesktopGui(args[0 .. 1], EamContainer.platformFromConfig(cfg));
			} else return guiMissing();

		case "webview":
			static if (guiAvailable) {
				configureLogging("warn");
				auto url = option(args, "--url");
				if (url is null) url = cfg.webviewUrl;
				if (url.length == 0) {
					startEmbeddedServer(cfg);
					url = "http://127.0.0.1:" ~ cfg.port.to!string ~ "/index.html";
				}
				return runWebView(args[0 .. 1], url);
			} else return guiMissing();

		default:
			configureLogging(option(args, "--verbose") !is null ? "info" : "warn");
			if (mode == "help" || mode == "-h" || mode == "--help" || "remote" in parseRemote(args))
				return runCli(args[1 .. $], null);
			return runCli(args[1 .. $], EamContainer.platformFromConfig(cfg, false));
	} catch (Exception e) {
		stderr.writeln("error: ", e.msg);
		return 1;
	}
}

/// The vibe.d server runs in its own thread with its own event loop; the GTK loop owns the main thread.
private void startEmbeddedServer(AppConfig cfg) {
	cfg.bindAddress = "127.0.0.1";
	auto t = new Thread({
		startHttpServer(cfg, EamContainer.platformFromConfig(cfg), new Authenticator(cfg));
		runEventLoop();
	});
	t.isDaemon = true;
	t.start();
	foreach (_; 0 .. 50) { // wait up to 5 s until the port accepts connections
		try {
			auto s = new TcpSocket(new InternetAddress("127.0.0.1", cfg.port));
			s.close();
			return;
		} catch (Exception) Thread.sleep(100.msecs);
	}
	throw new Exception("Embedded server did not start on port " ~ cfg.port.to!string);
}

private string option(string[] args, string name) {
	auto i = args.countUntil(name);
	if (i < 0) return null;
	return i + 1 < args.length ? args[i + 1] : "";
}

private string[string] parseRemote(string[] args) {
	string[string] r;
	if (auto v = option(args, "--remote")) r["remote"] = v;
	return r;
}

private int guiMissing() {
	stderr.writeln("This binary was built without GUI support. Build with: dub build -c desktop");
	return 3;
}
