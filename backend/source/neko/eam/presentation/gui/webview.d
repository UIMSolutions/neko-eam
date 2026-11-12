/// Desktop WebView: a GTK window embedding WebKit2GTK (4.1) that shows the Fiori app.
/// WebKit is loaded at runtime (dlopen), so no development headers are required to build.
module neko.eam.presentation.gui.webview;

version (EamGui):

import core.sys.posix.dlfcn : dlopen, dlsym, dlerror, RTLD_NOW;
import std.string : fromStringz, toStringz;
import gtk.Main;
import gtk.MainWindow;
import gtk.Widget;
import gtkc.gtktypes : GtkWidget;

private extern (C) nothrow @nogc {
	alias FnNew = GtkWidget* function();
	alias FnLoadUri = void function(void* webView, const(char)* uri);
}

private enum webkitLibraries = ["libwebkit2gtk-4.1.so.0", "libwebkit2gtk-4.0.so.37"];

/// Opens `url` in a native window. Returns the exit code.
int runWebView(string[] args, string url, string title = "Neko EAM") {
	Main.init(args);
	void* lib;
	foreach (name; webkitLibraries) {
		lib = dlopen(name.toStringz, RTLD_NOW);
		if (lib !is null) break;
	}
	if (lib is null)
		throw new Exception("WebKit2GTK not found (install libwebkit2gtk-4.1-0): " ~ dlerror().fromStringz.idup);
	auto webViewNew = cast(FnNew) dlsym(lib, "webkit_web_view_new");
	auto loadUri = cast(FnLoadUri) dlsym(lib, "webkit_web_view_load_uri");
	if (webViewNew is null || loadUri is null)
		throw new Exception("WebKit2GTK symbols not found");

	auto window = new MainWindow(title);
	window.setDefaultSize(1366, 860);
	auto raw = webViewNew();
	loadUri(raw, url.toStringz);
	window.add(new Widget(raw));
	window.showAll();
	Main.run();
	return 0;
}
