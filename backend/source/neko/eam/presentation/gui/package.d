/// Desktop / GUI integrations (GtkD native client and WebKit WebView).
/// Only available in the `desktop` dub configuration (version EamGui).
module neko.eam.presentation.gui;

version (EamGui) {
	public import neko.eam.presentation.gui.desktop;
	public import neko.eam.presentation.gui.webview;
	enum guiAvailable = true;
} else
	enum guiAvailable = false;
