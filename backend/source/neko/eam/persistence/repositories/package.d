/// Concrete repository implementations of the driven ports.
module neko.eam.persistence.repositories;

import std.traits : hasUDA, getUDAs, FieldNameTuple;
import std.algorithm : canFind, countUntil, remove;
import neko.eam.domain.types : References;
import neko.eam.ports.repositories;
import neko.eam.ports.storages;
import neko.eam.persistence.mappers;

/// Repository keeping entities in memory and writing through to an `IDocumentStorage`.
class DocumentRepository(TEntity, TRecord) : IElementRepository!TEntity {
	private {
		string _kind;
		IDocumentStorage _storage;
		TRecord[] _records; // insertion order preserved
	}

	this(string kind, IDocumentStorage storage) {
		_kind = kind;
		_storage = storage;
		foreach (doc; storage.load(kind)) _records ~= recordFromJson!TRecord(doc);
	}

	string kind() { return _kind; }
	size_t count() { return _records.length; }
	bool exists(string id) { return indexOf(id) >= 0; }

	TEntity[] findAll() {
		TEntity[] result;
		foreach (r; _records) result ~= copyFields!TEntity(r);
		return result;
	}

	TEntity findById(string id) {
		auto i = indexOf(id);
		return i < 0 ? null : copyFields!TEntity(_records[i]);
	}

	void save(TEntity entity) {
		auto rec = copyFields!TRecord(entity);
		auto i = indexOf(entity.id);
		if (i < 0) _records ~= rec;
		else _records[i] = rec;
		persist();
	}

	bool remove(string id) {
		auto i = indexOf(id);
		if (i < 0) return false;
		_records = _records.remove(i);
		persist();
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

	private ptrdiff_t indexOf(string id) {
		return _records.countUntil!(r => r.id == id);
	}

	private void persist() {
		Json[] docs;
		foreach (r; _records) docs ~= recordToJson(r);
		_storage.store(_kind, docs);
	}
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
