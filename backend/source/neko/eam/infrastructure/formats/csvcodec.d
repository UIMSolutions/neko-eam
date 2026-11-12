/// CSV (RFC 4180) tables: UTF-8 with BOM for Excel, separator auto-detection on import (`,` `;` tab),
/// Windows-1252 fallback for files saved by older Excel versions, and protection against formula injection.
module neko.eam.infrastructure.formats.csvcodec;

import std.algorithm : canFind, count, maxElement;
import std.array : appender;
import std.utf : validate, UTFException;
import neko.eam.application.dtos.transferdtos : TableDto;
import neko.eam.ports.services : ITableCodec;
import neko.eam.domain.exceptions : ValidationException;

class CsvCodec : ITableCodec {
	private char _separator;

	this(char separator = ',') { _separator = separator; }

	string format() { return "csv"; }
	string mimeType() { return "text/csv; charset=utf-8"; }

	immutable(ubyte)[] encode(TableDto[] sheets) {
		if (sheets.length != 1)
			throw new ValidationException("format", "CSV holds exactly one entity set - use XLSX for several");
		auto t = sheets[0];
		auto o = appender!string;
		o ~= "\xEF\xBB\xBF"; // BOM: Excel then opens the file as UTF-8
		void line(string[] cells, bool header) {
			foreach (i, cell; cells) {
				if (i) o ~= _separator;
				auto type = header || i >= t.types.length ? "String" : t.types[i];
				o ~= quote(guardFormula(cell, type));
			}
			o ~= "\r\n";
		}
		line(t.columns, true);
		foreach (r; t.rows) line(r, false);
		return cast(immutable(ubyte)[]) o.data;
	}

	TableDto[] decode(const(ubyte)[] data) {
		auto text = toUtf8(data);
		if (text.length >= 3 && text[0 .. 3] == "\xEF\xBB\xBF") text = text[3 .. $];
		auto sep = detectSeparator(text);
		string[][] records;
		string[] record;
		auto field = appender!string;
		bool inQuotes, any;
		void endField() {
			record ~= field.data.idup;
			field = appender!string;
		}
		void endRecord() {
			endField();
			records ~= record;
			record = null;
		}
		for (size_t i = 0; i < text.length; i++) {
			char c = text[i];
			any = true;
			if (inQuotes) {
				if (c == '"') {
					if (i + 1 < text.length && text[i + 1] == '"') { field ~= '"'; i++; }
					else inQuotes = false;
				} else field ~= c;
			} else if (c == '"' && field.data.length == 0) {
				inQuotes = true;
			} else if (c == sep) endField();
			else if (c == '\r' || c == '\n') {
				if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
				endRecord();
				any = false;
			} else field ~= c;
		}
		if (inQuotes) throw new ValidationException("file", "CSV: unterminated quoted field");
		if (any) endRecord();
		TableDto t;
		if (records.length) { t.columns = records[0]; t.rows = records[1 .. $]; }
		foreach (ref r; t.rows) foreach (ref cell; r) cell = unguardFormula(cell);
		return [t];
	}

	private string quote(string v) {
		if (!v.canFind(_separator) && !v.canFind('"') && !v.canFind('\n') && !v.canFind('\r')
			&& (v.length == 0 || (v[0] != ' ' && v[$ - 1] != ' ')))
			return v;
		auto o = appender!string;
		o ~= '"';
		foreach (char c; v) { if (c == '"') o ~= '"'; o ~= c; }
		o ~= '"';
		return o.data;
	}
}

/// Text cells starting with = + - @ would be executed as formulas by spreadsheet programs
/// (CSV injection); they are prefixed with an apostrophe, which Excel hides. Numbers stay unchanged.
string guardFormula(string v, string type) {
	if (v.length == 0 || (type != "String" && type != "StringCollection")) return v;
	if ("=+-@\t\r".canFind(v[0])) return "'" ~ v;
	return v;
}

/// Reverses `guardFormula`.
string unguardFormula(string v) {
	return v.length >= 2 && v[0] == '\'' && "=+-@\t\r".canFind(v[1]) ? v[1 .. $] : v;
}

/// Separator of the header line: the most frequent of `,` `;` and tab outside quotes.
char detectSeparator(string text) {
	size_t[char] n = [',': 0, ';': 0, '\t': 0];
	bool q;
	foreach (char c; text) {
		if (c == '"') q = !q;
		else if (!q && (c == '\n' || c == '\r')) break;
		else if (!q && c in n) n[c]++;
	}
	char best = ',';
	foreach (c; [';', '\t']) if (n[c] > n[best]) best = c;
	return best;
}

/// UTF-8 as is; anything else is read as Windows-1252 (German Excel "CSV (Trennzeichen-getrennt)").
string toUtf8(const(ubyte)[] data) {
	auto s = cast(string) data.idup;
	try { validate(s); return s; }
	catch (UTFException) {
		import std.encoding : transcode, Windows1252String;
		string r;
		transcode(cast(Windows1252String) data.idup, r);
		return r;
	}
}

unittest {
	auto c = new CsvCodec;
	TableDto t = TableDto("Applications", ["ID", "Name", "Note", "Cost"], ["String", "String", "String", "Double"],
		[["a1", "ERP, \"core\"", "=HYPERLINK(1)", "-5"], ["a2", "Line\nbreak", "", "0"]]);
	auto bytes = c.encode([t]);
	assert((cast(string) bytes)[0 .. 3] == "\xEF\xBB\xBF");
	assert((cast(string) bytes).canFind(`"ERP, ""core"""`) && (cast(string) bytes).canFind("'=HYPERLINK(1)"));
	auto back = c.decode(bytes)[0];
	assert(back.columns == t.columns && back.rows == t.rows);
	// German Excel: semicolons, Windows-1252 umlauts, no trailing newline
	auto de = c.decode(cast(const(ubyte)[]) "Name;Gr\xF6\xDFe\r\nM\xFCller;3")[0];
	assert(de.columns == ["Name", "Größe"] && de.rows == [["Müller", "3"]]);
	bool failed;
	try c.decode(cast(const(ubyte)[]) "a,\"b\n"); catch (ValidationException) failed = true;
	assert(failed);
}
