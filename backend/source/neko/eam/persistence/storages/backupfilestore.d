/// Backup files on disk: <directory>/<tenant>/<backupId>.eambackup (gzip-compressed JSON).
module neko.eam.persistence.storages.backupfilestore;

import std.algorithm : endsWith, map, sort;
import std.array : array;
static import std.file;
import std.file : dirEntries, mkdirRecurse, read, rename, SpanMode, write;
import std.path : baseName, buildPath, stripExtension;
import neko.eam.domain.entities.tenant : isValidTenantId;
import neko.eam.ports.services : IBackupStore;

enum backupExtension = ".eambackup";

class BackupFileStore : IBackupStore {
	private string _root;

	this(string directory) { _root = directory; }

	string[] list(string tenant) {
		auto dir = dirOf(tenant);
		if (!std.file.exists(dir)) return null;
		auto ids = dirEntries(dir, "*" ~ backupExtension, SpanMode.shallow).map!(e => e.name.baseName.stripExtension).array;
		ids.sort!((a, b) => a > b); // ids start with a UTC time stamp: newest first
		return ids;
	}

	void save(string tenant, string id, const(ubyte)[] data) {
		auto dir = dirOf(tenant);
		mkdirRecurse(dir);
		auto path = fileOf(tenant, id);
		write(path ~ ".tmp", data);
		rename(path ~ ".tmp", path);
	}

	immutable(ubyte)[] load(string tenant, string id) { return (cast(ubyte[]) read(fileOf(tenant, id))).idup; }

	void remove(string tenant, string id) { std.file.remove(fileOf(tenant, id)); }

	bool exists(string tenant, string id) { return isValidBackupId(id) && std.file.exists(fileOf(tenant, id)); }

	string location(string tenant) { return dirOf(tenant); }

	private string dirOf(string tenant) {
		if (!isValidTenantId(tenant)) throw new Exception("Invalid tenant id");
		return buildPath(_root, tenant);
	}

	private string fileOf(string tenant, string id) {
		if (!isValidBackupId(id)) throw new Exception("Invalid backup id '" ~ id ~ "'");
		return buildPath(dirOf(tenant), id ~ backupExtension);
	}
}

/// Backup ids become file names: letters, digits and '-' only (no path traversal).
bool isValidBackupId(string id) pure @safe {
	import std.ascii : isAlphaNum;
	if (id.length == 0 || id.length > 64) return false;
	foreach (char c; id) if (!(isAlphaNum(c) || c == '-')) return false;
	return true;
}

unittest {
	assert(isValidBackupId("20261112-101500-manual") && !isValidBackupId("../x") && !isValidBackupId("a/b"));
}

/// Volatile backup store (tests).
class MemoryBackupStore : IBackupStore {
	private immutable(ubyte)[][string][string] _files;

	string[] list(string tenant) {
		if (tenant !in _files) return null;
		auto ids = _files[tenant].keys;
		ids.sort!((a, b) => a > b);
		return ids;
	}
	void save(string tenant, string id, const(ubyte)[] data) { _files[tenant][id] = data.idup; }
	immutable(ubyte)[] load(string tenant, string id) { return _files[tenant][id]; }
	void remove(string tenant, string id) { _files[tenant].remove(id); }
	bool exists(string tenant, string id) { return tenant in _files && (id in _files[tenant]) !is null; }
	string location(string tenant) { return "memory:" ~ tenant; }
}
