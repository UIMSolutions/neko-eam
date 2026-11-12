/// XLSX (Office Open XML SpreadsheetML) tables, written and read with Phobos only (std.zip + a small XML scanner).
///
/// Export: one worksheet per table, bold frozen header row with auto filter, numbers and booleans as typed
/// cells, dates as real Excel dates (serial + date format), text as inline strings.
/// Import: shared and inline strings, numbers, booleans, formula results; first non-empty row is the header.
module neko.eam.infrastructure.formats.xlsxcodec;

import std.algorithm : min, max, canFind, startsWith, endsWith;
import std.array : appender, Appender;
import std.conv : to;
import std.format : formattedWrite;
import std.string : indexOf, toLower;
import std.zip;
import neko.eam.application.dtos.transferdtos : TableDto;
import neko.eam.ports.services : ITableCodec;
import neko.eam.domain.exceptions : ValidationException;

class XlsxCodec : ITableCodec {
	string format() { return "xlsx"; }
	string mimeType() { return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"; }

	immutable(ubyte)[] encode(TableDto[] sheets) {
		if (sheets.length == 0) throw new ValidationException("format", "XLSX needs at least one sheet");
		auto zip = new ZipArchive;
		void add(string name, string content) {
			auto m = new ArchiveMember;
			m.name = name;
			m.expandedData(cast(ubyte[]) content.dup);
			m.compressionMethod = CompressionMethod.deflate;
			zip.addMember(m);
		}
		string[] names = sheetNames(sheets);
		auto types = appender!string, wb = appender!string, rels = appender!string;
		types ~= `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` ~ "\n"
			~ `<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">`
			~ `<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>`
			~ `<Default Extension="xml" ContentType="application/xml"/>`
			~ `<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>`
			~ `<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>`;
		wb ~= `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` ~ "\n"
			~ `<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" `
			~ `xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>`;
		rels ~= `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` ~ "\n"
			~ `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">`;
		auto defined = appender!string;
		foreach (i, t; sheets) {
			auto n = i + 1;
			types.formattedWrite(`<Override PartName="/xl/worksheets/sheet%s.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`, n);
			wb.formattedWrite(`<sheet name="%s" sheetId="%s" r:id="rId%s"/>`, esc(names[i]), n, n);
			rels.formattedWrite(`<Relationship Id="rId%s" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet%s.xml"/>`, n, n);
			if (t.columns.length)
				defined.formattedWrite(`<definedName name="_xlnm._FilterDatabase" localSheetId="%s" hidden="1">'%s'!$A$1:$%s$%s</definedName>`,
					i, esc(names[i].replaceAll("'", "''")), columnName(t.columns.length - 1), t.rows.length + 1);
			add("xl/worksheets/sheet" ~ n.to!string ~ ".xml", worksheet(t));
		}
		types ~= `</Types>`;
		wb ~= `</sheets>`;
		if (defined.data.length) wb ~= `<definedNames>` ~ defined.data ~ `</definedNames>`;
		wb ~= `</workbook>`;
		rels.formattedWrite(`<Relationship Id="rId%s" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>`,
			sheets.length + 1);
		add("[Content_Types].xml", types.data);
		add("_rels/.rels", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` ~ "\n"
			~ `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">`
			~ `<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>`
			~ `</Relationships>`);
		add("xl/workbook.xml", wb.data);
		add("xl/_rels/workbook.xml.rels", rels.data);
		add("xl/styles.xml", stylesXml);
		return cast(immutable(ubyte)[]) zip.build().idup;
	}

	TableDto[] decode(const(ubyte)[] data) {
		ZipArchive zip;
		try zip = new ZipArchive(cast(void[]) data.dup);
		catch (Exception e) throw new ValidationException("file", "Not a valid XLSX file (" ~ e.msg ~ ")");
		string part(string name) {
			if (auto m = name in zip.directory) return cast(string) zip.expand(*m).idup;
			return null;
		}
		auto workbook = part("xl/workbook.xml");
		if (workbook is null) throw new ValidationException("file", "Not a valid XLSX file (xl/workbook.xml missing)");
		// relationship id -> worksheet part
		string[string] targets;
		foreach (e; XmlScanner(part("xl/_rels/workbook.xml.rels")))
			if (e.kind == XmlEvent.Kind.start && e.name == "Relationship") {
				auto target = e.attr("Target");
				if (target.startsWith("/")) target = target[1 .. $];
				else target = "xl/" ~ target;
				targets[e.attr("Id")] = target;
			}
		string[] sst = sharedStrings(part("xl/sharedStrings.xml"));
		TableDto[] result;
		foreach (e; XmlScanner(workbook))
			if (e.kind == XmlEvent.Kind.start && e.name == "sheet") {
				auto target = targets.get(e.attr("id"), "");
				auto xml = part(target);
				if (xml is null) continue;
				auto t = readSheet(xml, sst);
				t.name = e.attr("name");
				result ~= t;
			}
		if (result.length == 0) throw new ValidationException("file", "The XLSX file contains no worksheet");
		return result;
	}
}

private:

enum stylesXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` ~ "\n"
	~ `<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">`
	~ `<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>`
	~ `<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>`
	~ `<fill><patternFill patternType="solid"><fgColor rgb="FFDCE6F1"/><bgColor indexed="64"/></patternFill></fill></fills>`
	~ `<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>`
	~ `<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>`
	~ `<cellXfs count="4">`
	~ `<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>`
	~ `<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>`
	~ `<xf numFmtId="14" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>`
	~ `<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment wrapText="1" vertical="top"/></xf>`
	~ `</cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>`;

enum StyleHeader = 1, StyleDate = 2, StyleWrap = 3;

string worksheet(TableDto t) {
	auto o = appender!string;
	o ~= `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` ~ "\n"
		~ `<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">`
		~ `<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>`
		~ `<selection pane="bottomLeft" activeCell="A2" sqref="A2"/></sheetView></sheetViews>`
		~ `<sheetFormatPr defaultRowHeight="15"/>`;
	if (t.columns.length) {
		o ~= `<cols>`;
		foreach (c, h; t.columns) {
			size_t w = h.length + 2;
			foreach (r; t.rows[0 .. min($, 200)]) if (c < r.length) w = max(w, firstLine(r[c]).length + 2);
			o.formattedWrite(`<col min="%s" max="%s" width="%s" customWidth="1"/>`, c + 1, c + 1, min(w, 60));
		}
		o ~= `</cols>`;
	}
	o ~= `<sheetData>`;
	void row(size_t r, string[] cells, bool header) {
		o.formattedWrite(`<row r="%s">`, r);
		foreach (c, v; cells) {
			if (v.length == 0) continue;
			auto ref_ = columnName(c) ~ r.to!string;
			auto type = header || c >= t.types.length ? "String" : t.types[c];
			if (header) o.formattedWrite(`<c r="%s" s="%s" t="inlineStr"><is><t>%s</t></is></c>`, ref_, StyleHeader, esc(v));
			else if ((type == "Int32" || type == "Double") && isNumber(v)) o.formattedWrite(`<c r="%s"><v>%s</v></c>`, ref_, v);
			else if (type == "Boolean" && (v == "true" || v == "false")) o.formattedWrite(`<c r="%s" t="b"><v>%s</v></c>`, ref_, v == "true" ? 1 : 0);
			else if (type == "Date" && excelSerial(v) > 0) o.formattedWrite(`<c r="%s" s="%s"><v>%s</v></c>`, ref_, StyleDate, excelSerial(v));
			else o.formattedWrite(`<c r="%s"%s t="inlineStr"><is><t xml:space="preserve">%s</t></is></c>`, ref_,
				v.canFind('\n') ? ` s="3"` : "", esc(v));
		}
		o ~= `</row>`;
	}
	row(1, t.columns, true);
	foreach (i, r; t.rows) row(i + 2, r, false);
	o ~= `</sheetData>`;
	if (t.columns.length)
		o.formattedWrite(`<autoFilter ref="A1:%s%s"/>`, columnName(t.columns.length - 1), t.rows.length + 1);
	o ~= `</worksheet>`;
	return o.data;
}

/// Sheet names: max. 31 characters, without []:*?/\ and unique (case insensitive).
string[] sheetNames(TableDto[] sheets) {
	string[] names;
	bool[string] used;
	foreach (i, t; sheets) {
		string n;
		foreach (char c; t.name) if (!"[]:*?/\\".canFind(c)) n ~= c;
		if (n.length == 0) n = "Sheet" ~ (i + 1).to!string;
		if (n.length > 31) n = n[0 .. 31];
		auto base = n;
		for (int k = 2; n.toLower in used; k++) n = base[0 .. min($, 28)] ~ "_" ~ k.to!string;
		used[n.toLower] = true;
		names ~= n;
	}
	return names;
}

/// 0 -> "A", 25 -> "Z", 26 -> "AA"
string columnName(size_t index) {
	string s;
	size_t n = index + 1;
	while (n > 0) { s = cast(char)('A' + (n - 1) % 26) ~ s; n = (n - 1) / 26; }
	return s;
}

/// "AB12" -> column index 27 (0-based); -1 if malformed
long columnIndex(string cellRef) {
	long n;
	size_t i;
	for (; i < cellRef.length && cellRef[i] >= 'A' && cellRef[i] <= 'Z'; i++) n = n * 26 + (cellRef[i] - 'A' + 1);
	return i == 0 ? -1 : n - 1;
}

/// Excel date serial of an ISO date (days since 1899-12-30); 0 if not a date.
long excelSerial(string iso) {
	import std.datetime.date : Date;
	try return (Date.fromISOExtString(iso) - Date(1899, 12, 30)).total!"days";
	catch (Exception) return 0;
}

bool isNumber(string v) {
	try { v.to!double; return true; }
	catch (Exception) return false;
}

string firstLine(string v) {
	auto i = v.indexOf('\n');
	return i < 0 ? v : v[0 .. i];
}

string replaceAll(string s, string from, string to) {
	import std.array : replace;
	return s.replace(from, to);
}

/// XML text / attribute escaping; control characters that XML 1.0 forbids are dropped.
string esc(string s) {
	auto o = appender!string;
	foreach (char c; s) switch (c) {
		case '&': o ~= "&amp;"; break;
		case '<': o ~= "&lt;"; break;
		case '>': o ~= "&gt;"; break;
		case '"': o ~= "&quot;"; break;
		default:
			if (c < 0x20 && c != '\t' && c != '\n' && c != '\r') break;
			o ~= c;
	}
	return o.data;
}

/// Entity references and the OOXML escape `_xHHHH_` (used for control characters).
string unesc(string s) {
	if (!s.canFind('&') && !s.canFind("_x")) return s;
	auto o = appender!string;
	for (size_t i = 0; i < s.length; i++) {
		if (s[i] == '&') {
			auto end = s.indexOf(';', i);
			if (end > i) {
				auto ent = s[i + 1 .. end];
				dchar ch = 0;
				switch (ent) {
					case "amp": ch = '&'; break;
					case "lt": ch = '<'; break;
					case "gt": ch = '>'; break;
					case "quot": ch = '"'; break;
					case "apos": ch = '\''; break;
					default:
						try {
							if (ent.startsWith("#x")) ch = cast(dchar) ent[2 .. $].to!uint(16);
							else if (ent.startsWith("#")) ch = cast(dchar) ent[1 .. $].to!uint;
						} catch (Exception) {}
				}
				if (ch) { o ~= ch; i = end; continue; }
			}
		} else if (s[i] == '_' && i + 6 < s.length && s[i + 1] == 'x' && s[i + 6] == '_') {
			try {
				o ~= cast(dchar) s[i + 2 .. i + 6].to!uint(16);
				i += 6;
				continue;
			} catch (Exception) {}
		}
		o ~= s[i];
	}
	return o.data;
}

/// Pull scanner over XML: start/end tags (local names, prefixes stripped) and text. Comments, processing
/// instructions and DOCTYPEs are skipped; CDATA is returned as text. Sufficient for SpreadsheetML parts.
struct XmlEvent {
	enum Kind { start, end, text }
	Kind kind;
	string name;
	string[string] attrs;
	bool selfClosing;
	string text;

	string attr(string localName) const {
		if (auto p = localName in attrs) return *p;
		return "";
	}
}

struct XmlScanner {
	private string _s;
	private size_t _i;
	private XmlEvent _front;
	private bool _empty;
	private bool _pendingEnd;

	this(string s) {
		_s = s;
		popFront();
	}

	@property bool empty() const { return _empty; }
	@property XmlEvent front() { return _front; }

	void popFront() {
		if (_pendingEnd) { // synthetic end event of a self-closing tag
			_pendingEnd = false;
			_front = XmlEvent(XmlEvent.Kind.end, _front.name);
			return;
		}
		while (_i < _s.length) {
			if (_s[_i] != '<') {
				auto next = _s.indexOf('<', _i);
				auto end = next < 0 ? _s.length : next;
				_front = XmlEvent(XmlEvent.Kind.text, null, null, false, unesc(_s[_i .. end]));
				_i = end;
				return;
			}
			if (_s[_i .. $].startsWith("<![CDATA[")) {
				auto end = _s.indexOf("]]>", _i);
				if (end < 0) end = _s.length;
				_front = XmlEvent(XmlEvent.Kind.text, null, null, false, _s[_i + 9 .. end]);
				_i = min(_s.length, end + 3);
				return;
			}
			if (_s[_i .. $].startsWith("<!--")) { skipPast("-->"); continue; }
			if (_s[_i .. $].startsWith("<?") || _s[_i .. $].startsWith("<!")) { skipPast(">"); continue; }
			auto close = _s.indexOf('>', _i);
			if (close < 0) break;
			auto tag = _s[_i + 1 .. close];
			_i = close + 1;
			if (tag.startsWith("/")) {
				_front = XmlEvent(XmlEvent.Kind.end, localName(tag[1 .. $].strip));
				return;
			}
			bool selfClosing = tag.endsWith("/");
			if (selfClosing) tag = tag[0 .. $ - 1];
			size_t p;
			while (p < tag.length && !isSpace(tag[p])) p++;
			_front = XmlEvent(XmlEvent.Kind.start, localName(tag[0 .. p]), parseAttrs(tag[p .. $]), selfClosing);
			_pendingEnd = selfClosing;
			return;
		}
		_empty = true;
	}

	private void skipPast(string marker) {
		auto end = _s.indexOf(marker, _i);
		_i = end < 0 ? _s.length : end + marker.length;
	}

	private static string[string] parseAttrs(string s) {
		string[string] attrs;
		size_t i;
		while (i < s.length) {
			while (i < s.length && isSpace(s[i])) i++;
			auto nameStart = i;
			while (i < s.length && s[i] != '=' && !isSpace(s[i])) i++;
			auto name = s[nameStart .. i];
			while (i < s.length && (isSpace(s[i]) || s[i] == '=')) i++;
			if (i >= s.length || (s[i] != '"' && s[i] != '\'')) break;
			auto q = s[i++];
			auto valueStart = i;
			while (i < s.length && s[i] != q) i++;
			if (name.length) attrs[localName(name)] = unesc(s[valueStart .. min(i, s.length)]);
			i++;
		}
		return attrs;
	}
}

bool isSpace(char c) { return c == ' ' || c == '\t' || c == '\n' || c == '\r'; }

string strip(string s) {
	import std.string : sstrip = strip;
	return s.sstrip;
}

string localName(string qname) {
	auto colon = qname.indexOf(':');
	return colon < 0 ? qname : qname[colon + 1 .. $];
}

/// Shared string table; rich text runs are concatenated, phonetic runs (rPh) ignored.
string[] sharedStrings(string xml) {
	string[] result;
	if (xml is null) return result;
	auto buf = appender!string;
	bool inT;
	int phonetic;
	foreach (e; XmlScanner(xml)) final switch (e.kind) {
		case XmlEvent.Kind.start:
			if (e.name == "si") buf = appender!string;
			else if (e.name == "rPh") phonetic++;
			else if (e.name == "t" && phonetic == 0) inT = true;
			break;
		case XmlEvent.Kind.end:
			if (e.name == "si") result ~= buf.data;
			else if (e.name == "rPh") phonetic--;
			else if (e.name == "t") inT = false;
			break;
		case XmlEvent.Kind.text:
			if (inT) buf ~= e.text;
			break;
	}
	return result;
}

/// Cells of one worksheet -> table (first non-empty row = header, trailing empty columns dropped).
TableDto readSheet(string xml, string[] sst) {
	string[][size_t] cells; // row number -> cells
	size_t rowNo, maxCol;
	long col = -1;
	string type, value;
	bool inCell, inValue, inInline, inText;
	foreach (e; XmlScanner(xml)) final switch (e.kind) {
		case XmlEvent.Kind.start:
			switch (e.name) {
				case "row":
					auto r = e.attr("r");
					rowNo = r.length ? r.to!size_t : rowNo + 1;
					col = -1;
					break;
				case "c":
					auto r = e.attr("r");
					auto ci = r.length ? columnIndex(r) : -1;
					col = ci >= 0 ? ci : col + 1;
					type = e.attr("t");
					value = null;
					inCell = true;
					break;
				case "v": inValue = inCell; break;
				case "is": inInline = inCell; break;
				case "t": inText = inInline; break;
				default:
			}
			break;
		case XmlEvent.Kind.end:
			switch (e.name) {
				case "v": inValue = false; break;
				case "t": inText = false; break;
				case "is": inInline = false; break;
				case "c":
					inCell = false;
					string text;
					switch (type) {
						case "s":
							try text = sst[value.strip.to!size_t];
							catch (Exception) text = "";
							break;
						case "b": text = value.strip == "1" ? "true" : "false"; break;
						case "e": text = ""; break;
						default: text = value;
					}
					if (text.length) {
						auto rowCells = rowNo in cells;
						if (rowCells is null) { cells[rowNo] = null; rowCells = rowNo in cells; }
						if (rowCells.length <= col) rowCells.length = col + 1;
						(*rowCells)[col] = text;
						maxCol = max(maxCol, cast(size_t) col + 1);
					}
					break;
				default:
			}
			break;
		case XmlEvent.Kind.text:
			if (inValue || inText) value ~= e.text;
			break;
	}
	TableDto t;
	if (cells.length == 0) return t;
	import std.algorithm : sort;
	auto rowNumbers = cells.keys.sort;
	auto header = cells[rowNumbers[0]];
	header.length = maxCol;
	t.columns = header;
	foreach (r; rowNumbers[1 .. $]) {
		auto row = cells[r].dup;
		row.length = maxCol;
		t.rows ~= row;
	}
	return t;
}

unittest {
	assert(columnName(0) == "A" && columnName(25) == "Z" && columnName(26) == "AA" && columnName(701) == "ZZ");
	assert(columnIndex("AB12") == 27 && columnIndex("A1") == 0);
	assert(excelSerial("2025-01-01") == 45658);
	assert(unesc("a &amp; b &#x41;_x000D_") == "a & b A\r");

	auto c = new XlsxCodec;
	TableDto apps = TableDto("Applications", ["ID", "Name", "Cost", "Active", "Go-Live", "Caps"],
		["String", "String", "Double", "Boolean", "Date", "StringCollection"],
		[["a1", "ERP & <Core>", "1250.5", "true", "2023-04-01", "c1, c2"], ["a2", "Line\nbreak", "", "false", "", ""]]);
	TableDto orgs = TableDto("Organizations", ["ID", "Name"], ["String", "String"], [["o1", "Müller GmbH"]]);
	auto bytes = c.encode([apps, orgs]);
	assert(bytes[0 .. 2] == "PK");
	auto back = c.decode(bytes);
	assert(back.length == 2 && back[0].name == "Applications" && back[1].name == "Organizations");
	assert(back[0].columns == apps.columns);
	assert(back[0].rows[0] == ["a1", "ERP & <Core>", "1250.5", "true", "45017", "c1, c2"]);
	assert(back[0].rows[1] == ["a2", "Line\nbreak", "", "false", "", ""]);
	assert(back[1].rows == [["o1", "Müller GmbH"]]);
	assert(sheetNames([TableDto("a/b"), TableDto("A_B"), TableDto("ab")]) == ["ab", "A_B", "ab_2"]);

	// shared strings and rich text as written by Excel
	auto sst = `<sst><si><t>Name</t></si><si><r><t>Ri</t></r><r><t>ch</t></r><rPh><t>x</t></rPh></si></sst>`;
	auto sheet = `<worksheet><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c></row>`
		~ `<row r="3"><c r="A3" t="s"><v>1</v></c><c r="C3"><v>7</v></c></row></sheetData></worksheet>`;
	auto t = readSheet(sheet, sharedStrings(sst));
	assert(t.columns == ["Name", null, null] && t.rows == [["Rich", null, "7"]]);
	bool failed;
	try c.decode(cast(const(ubyte)[]) "not a zip"); catch (ValidationException) failed = true;
	assert(failed);
}
