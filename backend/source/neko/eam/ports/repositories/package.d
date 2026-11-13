/// Driven ports for business data access.
module neko.eam.ports.repositories;

import neko.eam.domain.entities.tenant : Tenant;
import neko.eam.domain.entities.comment : Comment;
import neko.eam.domain.entities.credential : Credential;
import neko.eam.domain.entities.activity : Activity, NotificationState;

/// Kind independent repository operations (used for referential integrity checks).
interface IElementRepositoryBase {
	/// Element kind (entity set name), e.g. "Applications".
	string kind();
	bool exists(string id);
	size_t count();
	/// Change counter: increases with every save / remove (cache invalidation).
	ulong changeCount();
	/// Ids of elements in this repository that reference element `id` of `kind`.
	string[] findReferencing(string kind, string id);
}

/// Typed repository of a domain entity.
interface IElementRepository(TEntity) : IElementRepositoryBase {
	/// Fresh copies of all elements (the caller may modify them).
	TEntity[] findAll();
	/// Shared read-only view of all elements, rebuilt only after a change - no copies per call.
	/// Callers must not modify the returned entities (use `findAll` / `findById` for that).
	TEntity[] readAll();
	/// Shared read-only view by id (same rules as `readAll`).
	TEntity[string] readMap();
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

/// Driven port: the passwords (hashes) of the users of one tenant - local sign-in only.
interface ICredentialRepository {
	/// null if the user has no password
	Credential find(string userId);
	void save(Credential credential);
	/// Removes the password of a user (no-op if there is none).
	void remove(string userId);
	size_t count();
}

/// Driven port: the recent activities of one tenant (bounded journal, oldest first).
interface IActivityRepository {
	void add(Activity activity);
	/// All kept activities, oldest first (shared - read only).
	Activity[] all();
	size_t count();
}

/// Driven port: read / dismissed notifications per user of one tenant.
interface INotificationStateRepository {
	/// null if the user has no state yet
	NotificationState find(string user);
	void save(NotificationState state);
}
