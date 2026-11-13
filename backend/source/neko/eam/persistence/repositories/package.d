/// Concrete repository implementations of the driven ports.
module neko.eam.persistence.repositories;

import std.traits : hasUDA, getUDAs, FieldNameTuple;
import std.algorithm : canFind, countUntil, remove;
import neko.eam.domain.types : References;
import neko.eam.ports.repositories;
import neko.eam.ports.storages;
import neko.eam.persistence.mappers;

/// Repository keeping entities in memory and writing through to an `IDocumentStorage`.
///
/// Lookups by id use a hash index. The JSON documents are kept in step with the records, so that a save
/// converts only the changed element (not the whole collection). `readAll` / `readMap` hand out one shared
/// set of entities per change, for read-time roll-ups and access checks that would otherwise copy the whole
/// collection on every call.
class DocumentRepository(TEntity, TRecord) : IElementRepository!TEntity {
	private {
		string _kind;
		IDocumentStorage _storage;
		TRecord[] _records;     // insertion order preserved
		Json[] _docs;           // JSON form of `_records` (same order)
		size_t[string] _index;  // id -> position in `_records`
		TEntity[] _snapshot;    // shared read-only entities (valid while `_snapshotValid`)
		TEntity[string] _snapshotById;
		bool _snapshotValid;
		ulong _changes;
	}

	this(string kind, IDocumentStorage storage) {
		_kind = kind;
		_storage = storage;
		foreach (doc; storage.load(kind)) {
			auto rec = recordFromJson!TRecord(doc);
			if (rec.id in _index) continue; // duplicate id in the file: the first one wins (as lookups always did)
			_index[rec.id] = _records.length;
			_records ~= rec;
			_docs ~= recordToJson(rec);
		}
	}

	string kind() { return _kind; }
	size_t count() { return _records.length; }
	bool exists(string id) { return (id in _index) !is null; }
	ulong changeCount() { return _changes; }

	TEntity[] findAll() {
		auto result = new TEntity[_records.length];
		foreach (i, ref r; _records) result[i] = copyFields!TEntity(r);
		return result;
	}

	TEntity[] readAll() {
		buildSnapshot();
		return _snapshot;
	}

	TEntity[string] readMap() {
		buildSnapshot();
		return _snapshotById;
	}

	TEntity findById(string id) {
		if (auto p = id in _index) return copyFields!TEntity(_records[*p]);
		return null;
	}

	void save(TEntity entity) {
		auto rec = copyFields!TRecord(entity);
		auto doc = recordToJson(rec);
		if (auto p = entity.id in _index) {
			_records[*p] = rec;
			_docs[*p] = doc;
		} else {
			_index[entity.id] = _records.length;
			_records ~= rec;
			_docs ~= doc;
		}
		changed();
	}

	bool remove(string id) {
		auto p = id in _index;
		if (p is null) return false;
		auto i = *p;
		_records = _records.remove(i);
		_docs = _docs.remove(i);
		_index.remove(id);
		foreach (j; i .. _records.length) _index[_records[j].id] = j;
		changed();
		return true;
	}

	string[] findReferencing(string kind, string id) {
		string[] result;
		foreach (r; _records) {
			bool hit;
			static foreach (name; FieldNameTuple!TEntity) {
				static if (hasUDA!(__traits(getMember, TEntity, name), References)) {
					if (getUDAs!(__traits(getMember, TEntity, name), References)[0].kind == kind) {
						auto v = __traits(getMember, r, name);
						static if (is(typeof(v) : const(string[]))) hit = hit || v.canFind(id);
						else hit = hit || v == id;
					}
				}
			}
			if (hit && !(kind == _kind && r.id == id)) result ~= r.id;
		}
		return result;
	}

	private void buildSnapshot() {
		if (_snapshotValid) return;
		auto all = new TEntity[_records.length];
		TEntity[string] byId;
		foreach (i, ref r; _records) {
			all[i] = copyFields!TEntity(r);
			byId[r.id] = all[i];
		}
		_snapshot = all;
		_snapshotById = byId;
		_snapshotValid = true;
	}

	private void changed() {
		_changes++;
		_snapshotValid = false;
		_snapshot = null;
		_snapshotById = null;
		_storage.store(_kind, _docs);
	}
}

unittest {
	import neko.eam.domain.entities : Application;
	import neko.eam.persistence.records : ApplicationRecord;
	import neko.eam.persistence.storages.memorystorage : MemoryStorage;
	auto storage = new MemoryStorage;
	auto repo = new DocumentRepository!(Application, ApplicationRecord)("Applications", storage);
	foreach (id; ["a", "b", "c"]) { auto e = new Application; e.id = id; e.name = id.idup; repo.save(e); }
	auto snap = repo.readAll;
	assert(snap.length == 3 && repo.readAll is snap, "snapshot is shared until the next change");
	assert(repo.readMap["b"].name == "b");
	auto before = repo.changeCount;
	assert(repo.remove("a") && !repo.exists("a") && repo.findById("c").name == "c");
	assert(repo.changeCount > before && repo.readAll.length == 2 && repo.readAll !is snap);
	auto c = repo.findById("c");
	c.name = "C";
	repo.save(c);
	assert(repo.findById("c").name == "C" && repo.count == 2);
	auto reloaded = new DocumentRepository!(Application, ApplicationRecord)("Applications", storage);
	assert(reloaded.count == 2 && reloaded.findById("b") !is null && reloaded.findById("c").name == "C");
	assert(storage.load("Applications").length == 2);
}

/// Registry of all repositories by kind.
class RepositoryRegistry : IRepositoryRegistry {
	private IElementRepositoryBase[] _repos;

	void register(IElementRepositoryBase repo) { _repos ~= repo; }

	IElementRepositoryBase byKind(string kind) {
		foreach (r; _repos) if (r.kind == kind) return r;
		return null;
	}

	IElementRepositoryBase[] all() { return _repos; }
}
public import neko.eam.persistence.repositories.tenantregistry;
public import neko.eam.persistence.repositories.commentrepository;
public import neko.eam.persistence.repositories.credentialrepository;
public import neko.eam.persistence.repositories.activityrepository;
