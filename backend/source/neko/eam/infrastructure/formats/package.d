/// Table file formats (CSV, XLSX) implementing the ITableCodec port. Pure: no I/O, no framework.
module neko.eam.infrastructure.formats;

public import neko.eam.infrastructure.formats.csvcodec;
public import neko.eam.infrastructure.formats.xlsxcodec;

import neko.eam.ports.services : ITableCodec;
import neko.eam.domain.exceptions : ValidationException;

/// Codec by format name or file extension ("csv", "xlsx", "report.xlsx"). `separator` only applies to CSV.
ITableCodec codecFor(string formatOrFile, char separator = ',') {
	import std.string : toLower, lastIndexOf;
	auto f = formatOrFile.toLower;
	auto dot = f.lastIndexOf('.');
	if (dot >= 0) f = f[dot + 1 .. $];
	switch (f) {
		case "csv", "txt": return new CsvCodec(separator);
		case "xlsx": return new XlsxCodec;
		default: throw new ValidationException("format", "Unsupported format '" ~ formatOrFile ~ "' (use csv or xlsx)");
	}
}

/// Codec for uploaded bytes: XLSX files are ZIP archives ("PK\x03\x04"), everything else is read as CSV.
ITableCodec codecForContent(const(ubyte)[] data) {
	return data.length >= 4 && data[0 .. 4] == [0x50, 0x4B, 0x03, 0x04] ? cast(ITableCodec) new XlsxCodec : new CsvCodec;
}
public import neko.eam.infrastructure.formats.pdfreport;
