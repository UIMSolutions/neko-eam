/// Minimal PDF writer for reports (no external library): A4 landscape, Helvetica (WinAnsi encoding),
/// a title page block per report (set, filter, time, row count), the table with repeated header on each page,
/// the group summary and page numbers.
module neko.eam.infrastructure.formats.pdfreport;

import std.algorithm : max, min, sum;
import std.array : appender, Appender;
import std.conv : to;
static import std.format;
import std.utf : byDchar;
import neko.eam.application.dtos.platformdtos : ReportResultDto;
import neko.eam.ports.services : IReportRenderer;

class PdfReportRenderer : IReportRenderer {
	string format() { return "pdf"; }
	string mimeType() { return "application/pdf"; }

	immutable(ubyte)[] render(string title, ReportResultDto[] results) {
		auto doc = new PdfDocument;
		foreach (i, r; results) {
			if (i) doc.newPage();
			doc.heading(r.name.length ? r.name : r.setLabel, i == 0 && title.length && title != r.name ? title : "");
			string meta = r.setLabel ~ "  ·  " ~ r.totalCount.to!string ~ " rows";
			if (r.filter.length) meta ~= "  ·  Filter: " ~ r.filter;
			doc.text(meta, 8, false);
			doc.text("Generated " ~ r.generatedAt ~ (r.generatedBy.length ? " by " ~ r.generatedBy : ""), 8, false);
			if (r.description.length) doc.text(r.description, 8, false);
			doc.gap(6);
			string[] headers;
			foreach (c; r.columns) headers ~= c.label;
			bool[] numeric;
			foreach (c; r.columns) numeric ~= c.type == "Int32" || c.type == "Double";
			doc.table(headers, r.rows, numeric);
			if (r.groups.length) {
				doc.gap(10);
				doc.text("Summary by " ~ r.groupLabel, 10, true);
				string[][] rows;
				foreach (g; r.groups)
					rows ~= [g.value, g.count.to!string] ~ (r.sumField.length ? [std.format.format("%.2f", g.sum)] : null);
				doc.table([r.groupLabel, "Count"] ~ (r.sumField.length ? [r.sumLabel] : null), rows,
					[false, true] ~ (r.sumField.length ? [true] : null));
			}
		}
		return doc.finish();
	}
}

/// Page layout and object writer.
private final class PdfDocument {
	enum width = 842.0, height = 595.0, margin = 36.0;
	private string[] _pages;            // content streams
	private Appender!string _cur;
	private double _y;

	this() { newPage(); }

	void newPage() {
		if (_cur.data.length) _pages ~= _cur.data;
		_cur = appender!string;
		_y = height - margin;
	}

	void gap(double h) { _y -= h; }

	void heading(string text, string subtitle) {
		if (subtitle.length) this.text(subtitle, 9, false);
		this.text(text, 15, true);
		gap(2);
	}

	void text(string s, double size, bool bold) {
		ensure(size + 4);
		_y -= size + 3;
		put(margin, _y, size, bold, fit(s, width - 2 * margin, size));
	}

	void table(string[] headers, string[][] rows, bool[] numeric) {
		enum size = 7.5, rowH = 11.0;
		auto avail = width - 2 * margin;
		// column widths proportional to the longest text (capped), at least 6 % each
		double[] want;
		foreach (i, h; headers) {
			size_t w = h.length;
			foreach (r; rows) if (i < r.length) w = max(w, min(r[i].length, 48));
			want ~= max(cast(double) w, 4.0);
		}
		auto total = want.sum;
		double[] cols;
		foreach (w; want) cols ~= max(avail * w / total, avail * 0.06);
		auto scale = avail / cols.sum;
		foreach (ref c; cols) c *= scale;

		void headerRow() {
			ensure(rowH * 2);
			_y -= rowH;
			_cur ~= std.format.format("0.85 0.88 0.93 rg %.1f %.1f %.1f %.1f re f 0 g\n", margin, _y - 3, avail, rowH);
			double x = margin;
			foreach (i, h; headers) {
				auto t = fit(h, cols[i] - 10, size);
				put(numeric.length > i && numeric[i] ? x + cols[i] - 8 - textWidth(t, size) : x + 2, _y, size, true, t);
				x += cols[i];
			}
		}
		headerRow();
		foreach (ri, r; rows) {
			if (_y - rowH < margin + 14) { newPage(); headerRow(); }
			_y -= rowH;
			if (ri % 2 == 1)
				_cur ~= std.format.format("0.96 0.96 0.96 rg %.1f %.1f %.1f %.1f re f 0 g\n", margin, _y - 3, avail, rowH);
			double x = margin;
			foreach (i; 0 .. headers.length) {
				auto cell = fit(i < r.length ? r[i] : "", cols[i] - 10, size);
				auto tx = numeric.length > i && numeric[i] ? x + cols[i] - 8 - textWidth(cell, size) : x + 2;
				put(tx, _y, size, false, cell);
				x += cols[i];
			}
		}
	}

	immutable(ubyte)[] finish() {
		if (_cur.data.length) _pages ~= _cur.data;
		auto o = appender!string;
		size_t[] offsets;
		o ~= "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n";
		void obj(size_t n, string body) {
			offsets ~= o.data.length;
			o ~= std.format.format("%s 0 obj\n%s\nendobj\n", n, body);
		}
		immutable n = _pages.length;
		// 1 catalog, 2 pages, 3 Helvetica, 4 Helvetica-Bold, then page / content pairs
		string kids;
		foreach (i; 0 .. n) kids ~= std.format.format("%s 0 R ", 5 + 2 * i);
		obj(1, "<< /Type /Catalog /Pages 2 0 R >>");
		obj(2, std.format.format("<< /Type /Pages /Kids [%s] /Count %s >>", kids, n));
		obj(3, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>");
		obj(4, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>");
		foreach (i, content; _pages) {
			auto footer = std.format.format("BT /F1 7 Tf %.1f %.1f Td (%s) Tj ET\n", width - margin - 40, margin - 18,
				escape(std.format.format("Page %s / %s", i + 1, n)));
			auto stream = content ~ footer;
			obj(5 + 2 * i, std.format.format("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %s %s] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents %s 0 R >>",
				cast(int) width, cast(int) height, 6 + 2 * i));
			obj(6 + 2 * i, std.format.format("<< /Length %s >>\nstream\n%s\nendstream", stream.length + 1, stream));
		}
		auto xref = o.data.length;
		o ~= std.format.format("xref\n0 %s\n0000000000 65535 f \n", offsets.length + 1);
		foreach (off; offsets) o ~= std.format.format("%010d 00000 n \n", off);
		o ~= std.format.format("trailer\n<< /Size %s /Root 1 0 R >>\nstartxref\n%s\n%%%%EOF\n", offsets.length + 1, xref);
		return (cast(immutable(ubyte)[]) o.data);
	}

	private void ensure(double h) { if (_y - h < margin + 14) newPage(); }

	private void put(double x, double y, double size, bool bold, string s) {
		_cur ~= std.format.format("BT /%s %.1f Tf %.1f %.1f Td (%s) Tj ET\n", bold ? "F2" : "F1", size, x, y, escape(s));
	}
}

/// Shortens `s` with an ellipsis to fit `maxWidth` points.
private string fit(string s, double maxWidth, double size) {
	if (textWidth(s, size) <= maxWidth) return s;
	dchar[] chars;
	foreach (dchar c; s.byDchar) chars ~= c;
	while (chars.length && textWidth(chars.to!string ~ "…", size) > maxWidth) chars = chars[0 .. $ - 1];
	return chars.to!string ~ "…";
}

/// Approximate Helvetica width (average glyph widths are good enough for column fitting).
private double textWidth(string s, double size) {
	double w = 0;
	foreach (dchar c; s.byDchar)
		w += c == ' ' || c == 'i' || c == 'l' || c == '.' || c == ',' || c == '|' ? 0.28
			: c >= 'A' && c <= 'Z' || c == 'm' || c == 'w' || c == '%' ? 0.67 : 0.53;
	return w * size;
}

/// UTF-8 -> WinAnsi (cp1252) with PDF string escapes; characters outside cp1252 become '?'.
private string escape(string s) {
	auto o = appender!string;
	foreach (dchar c; s.byDchar) {
		uint b;
		switch (c) {
			case '€': b = 0x80; break;
			case '„': b = 0x84; break;
			case '…': b = 0x85; break;
			case '‘': b = 0x91; break;
			case '’': b = 0x92; break;
			case '“': b = 0x93; break;
			case '”': b = 0x94; break;
			case '•': b = 0x95; break;
			case '–': b = 0x96; break;
			case '—': b = 0x97; break;
			default: b = c < 0x80 || (c >= 0xA0 && c <= 0xFF) ? c : '?';
		}
		if (b == '(' || b == ')' || b == '\\') { o ~= '\\'; o ~= cast(char) b; }
		else if (b < 0x20) o ~= ' ';
		else if (b < 0x80) o ~= cast(char) b;
		else o ~= std.format.format("\\%03o", b);
	}
	return o.data;
}

unittest {
	import std.algorithm : canFind;
	import neko.eam.application.dtos.platformdtos : ReportColumnDto, ReportGroupDto;
	ReportResultDto r;
	r.name = "Application portfolio (Ä)";
	r.setLabel = "Applications";
	r.columns = [ReportColumnDto("name", "Name", "String"), ReportColumnDto("annualCost", "Annual Cost", "Double")];
	foreach (i; 0 .. 120) r.rows ~= ["App " ~ i.to!string, "1000"];
	r.groupLabel = "TIME"; r.groups = [ReportGroupDto("Invest", 3)];
	auto pdf = cast(string) new PdfReportRenderer().render("Board", [r]);
	assert(pdf[0 .. 8] == "%PDF-1.4" && pdf.canFind("%%EOF"));
	assert(!pdf.canFind("/Count 1 ") && !pdf.canFind("/Count 2 "), "120 rows need more than two pages");
	assert(escape("Ä(x)€") == `\304\(x\)\200`);
	assert(fit("a very long text that does not fit", 40, 8).canFind("…"));
}
