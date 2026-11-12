/// Driven ports for business data access.
module neko.eam.ports.repositories;

import neko.eam.domain.entities.tenant : Tenant;
import neko.eam.domain.entities.comment : Comment;

/// Kind independent repository operations (used for referential integrity checks).
interface IElementRepositoryBase {
	/// Element kind (entity set name), e.g. "Applications".
	string kind();
	bool exists(string id);
	size_t count();
	/// Ids of elements in this repository that reference element `id` of `kind`.
	string[] findReferencing(string kind, string id);
}

/// Typed repository of a domain entity.
interface IElementRepository(TEntity) : IElementRepositoryBase {
	TEntity[] findAll();
	/// Returns null if not found.
	TEntity findById(string id);
	void save(TEntity entity);
	bool remove(string id);
}

/// Lookup of repositories by kind.
interface IRepositoryRegistry {
	IElementRepositoryBase byKind(string kind);
	IElementRepositoryBase[] all();
}

/// Driven port: the tenants of the platform (stored outside of every tenant's repository).
interface ITenantRegistry {
	Tenant[] all();
	/// null if unknown
	Tenant find(string id);
	void save(Tenant tenant);
	void remove(string id);
}

/// Driven port: the comment journal of the elements of one tenant.
interface ICommentRepository {
	/// Comments of one element, oldest first.
	Comment[] forElement(string elementSet, string elementId);
	/// null if unknown
	Comment find(string id);
	void save(Comment comment);
	void remove(string id);
	/// Removes all comments of an element (when the element is deleted); returns the number removed.
	size_t removeForElement(string elementSet, string elementId);
	size_t count();
}
