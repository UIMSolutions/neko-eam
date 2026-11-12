/// Backup file format: gzip-compressed JSON with a manifest and a SHA-256 checksum over the canonical data.
///
///   { "format": "neko-eam-backup", "version": 1, "tenant": "...", "tenantName": "...", "createdAt": "...",
///     "createdBy": "...", "kind": "Manual", "comment": "...", "counts": { "<collection>": n },
///     "checksum": "<sha256 hex>", "collections": { "<collection>": [ <documents> ] } }
///
/// The checksum is computed over a canonical serialisation (object keys sorted), so it does not depend on
/// the key order of a JSON library. Plain (uncompressed) JSON is accepted on restore as well.
module neko.eam.application.services.backupcodec;

import std.algorithm : sort;
import std.array : appender, Appender;
import std.conv : to;
import std.digest : toHexString, LetterCase;
import std.digest.sha : sha256Of;
import std.zlib : Compress, UnCompress, HeaderFormat;
import vibe.data.json;
import neko.eam.domain.exceptions : ValidationException;
import neko.eam.application.dtos.platformdtos;

enum backupFormat = "neko-eam-backup";
enum backupVersion = 1;

/// A decoded backup.
struct BackupSnapshot {
	BackupInfoDto info;
	Json[][string] collections;
}

/// Serialises and compresses a snapshot; fills `info.checksum`, `info.counts`, `info.elements`, `info.sizeBytes`.
immutable(ubyte)[] encodeBackup(ref BackupInfoDto info, Json[][string] collections) {
	info.checksum = checksumOf(collections);
	info.counts = null;
	info.elements = 0;
	auto counts = Json.emptyObject;
	auto cols = Json.emptyObject;
	foreach (name; sortedKeys(collections)) {
		info.counts ~= SetCountDto(name, collections[name].length);
		info.elements += collections[name].length;
		counts[name] = collections[name].length;
		cols[name] = Json(collections[name]);
	}
	auto root = Json.emptyObject;
	root["format"] = backupFormat;
	root["version"] = backupVersion;
	root["id"] = info.id;
	root["tenant"] = info.tenant;
	root["tenantName"] = info.tenantName;
	root["createdAt"] = info.createdAt;
	root["createdBy"] = info.createdBy;
	root["kind"] = info.kind;
	root["comment"] = info.comment;
	root["counts"] = counts;
	root["checksum"] = info.checksum;
	root["collections"] = cols;
	auto c = new Compress(9, HeaderFormat.gzip);
	auto data = cast(ubyte[]) c.compress(root.toString());
	data ~= cast(ubyte[]) c.flush();
	info.sizeBytes = data.length;
	return data.idup;
}

/// Reads the manifest only (listing) - still decompresses, but does not verify the checksum.
BackupInfoDto readBackupInfo(const(ubyte)[] file) {
	return decode(file, false).info;
}

/// Decodes and verifies a backup file. Throws ValidationException for foreign, newer or damaged files.
BackupSnapshot decodeBackup(const(ubyte)[] file) {
	return decode(file, true);
}

private BackupSnapshot decode(const(ubyte)[] file, bool verify) {
	string text;
	try {
		if (file.length >= 2 && file[0] == 0x1f && file[1] == 0x8b) {
			auto u = new UnCompress(HeaderFormat.gzip);
			auto raw = cast(const(ubyte)[]) u.uncompress(file.dup);
			raw ~= cast(const(ubyte)[]) u.flush();
			text = cast(string) raw.idup;
		} else text = cast(string) file.idup;
	} catch (Exception e) throw new ValidationException("file", "Not a readable backup file: " ~ e.msg);
	Json root;
	try root = parseJsonString(text);
	catch (Exception e) throw new ValidationException("file", "Backup file is not valid JSON: " ~ e.msg);
	if (root.type != Json.Type.object || root["format"].opt!string("") != backupFormat)
		throw new ValidationException("file", "Not an Neko EAM backup (format '" ~ backupFormat ~ "' expected)");
	auto ver = root["version"].opt!int(0);
	if (ver < 1 || ver > backupVersion)
		throw new ValidationException("file", "Backup format version " ~ ver.to!string ~ " is not supported (max " ~ backupVersion.to!string ~ ")");
	BackupSnapshot s;
	s.info.id = root["id"].opt!string("");
	s.info.tenant = root["tenant"].opt!string("");
	s.info.tenantName = root["tenantName"].opt!string("");
	s.info.createdAt = root["createdAt"].opt!string("");
	s.info.createdBy = root["createdBy"].opt!string("");
	s.info.kind = root["kind"].opt!string("");
	s.info.comment = root["comment"].opt!string("");
	s.info.checksum = root["checksum"].opt!string("");
	s.info.sizeBytes = file.length;
	if (root["collections"].type != Json.Type.object)
		throw new ValidationException("file", "Backup file has no collections");
	foreach (string name, docs; root["collections"]) {
		if (docs.type != Json.Type.array) throw new ValidationException("file", "Collection '" ~ name ~ "' is not an array");
		Json[] list;
		foreach (d; docs) list ~= d;
		s.collections[name] = list;
	}
	foreach (name; sortedKeys(s.collections)) {
		s.info.counts ~= SetCountDto(name, s.collections[name].length);
		s.info.elements += s.collections[name].length;
	}
	if (verify && checksumOf(s.collections) != s.info.checksum)
		throw new ValidationException("checksum", "Checksum mismatch - the backup file is damaged or was modified");
	return s;
}

/// SHA-256 (hex) of the canonical serialisation of all collections.
string checksumOf(Json[][string] collections) {
	auto w = appender!string;
	foreach (name; sortedKeys(collections)) {
		w ~= name;
		w ~= "\n";
		foreach (d; collections[name]) { canonical(w, d); w ~= "\n"; }
	}
	return toHexString!(LetterCase.lower)(sha256Of(w.data)).idup;
}

/// JSON with sorted object keys (stable across libraries and key orders).
void canonical(ref Appender!string w, Json j) {
	if (j.type == Json.Type.object) {
		string[] keys;
		foreach (string k, v; j) keys ~= k;
		keys.sort();
		w ~= "{";
		foreach (i, k; keys) {
			if (i) w ~= ",";
			w ~= Json(k).toString();
			w ~= ":";
			canonical(w, j[k]);
		}
		w ~= "}";
	} else if (j.type == Json.Type.array) {
		w ~= "[";
		foreach (size_t i, ref Json v; j) {
			if (i) w ~= ",";
			canonical(w, v);
		}
		w ~= "]";
	} else w ~= j.toString();
}

private string[] sortedKeys(Json[][string] m) {
	auto k = m.keys;
	k.sort();
	return k;
}

unittest {
	Json[][string] data = ["Applications": [Json(["id": Json("a1"), "name": Json("CRM")])], "Products": []];
	BackupInfoDto info = { id: "b1", tenant: "acme", createdAt: "2026-11-12T10:00:00Z", kind: "Manual" };
	auto file = encodeBackup(info, data);
	assert(file[0] == 0x1f && info.elements == 1 && info.checksum.length == 64);
	auto s = decodeBackup(file);
	assert(s.info.tenant == "acme" && s.collections["Applications"][0]["name"].get!string == "CRM");

	// key order does not change the checksum
	Json a = Json.emptyObject; a["x"] = 1; a["y"] = 2;
	Json b = Json.emptyObject; b["y"] = 2; b["x"] = 1;
	assert(checksumOf(["C": [a]]) == checksumOf(["C": [b]]));

	// tampering is detected
	auto u = new UnCompress(HeaderFormat.gzip);
	auto text = cast(string) (cast(ubyte[]) u.uncompress(file.dup) ~ cast(ubyte[]) u.flush()).idup;
	import std.string : replace;
	bool failed;
	try decodeBackup(cast(const(ubyte)[]) text.replace("CRM", "XRM")); catch (ValidationException e) failed = e.field == "checksum";
	assert(failed, "modified plain JSON fails the checksum");
	failed = false;
	try decodeBackup(cast(const(ubyte)[]) `{"format":"other"}`); catch (ValidationException e) failed = e.field == "file";
	assert(failed);
}
