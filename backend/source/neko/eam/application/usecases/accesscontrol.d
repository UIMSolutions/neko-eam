/// Access control: resolves the effective rights of the caller from the users, roles and permissions of
/// the repository and hands out a checked view of the use cases (decorators around every driving port).
///
/// Resolution order:
///   1. administrator subject (XSUAA Admin scope, local operation without impersonation) -> unrestricted
///   2. repository user with the same user name or e-mail (case-insensitive) -> rights of its active roles
///   3. no users defined yet (fresh installation) -> read access to everything except access management
///   4. otherwise -> no rights
///
/// It also owns the passwords of the local sign-in (`authMode=local`): they are kept in a separate credential
/// store (never exposed as element data) and checked against a salted hash.
module neko.eam.application.usecases.accesscontrol;

import std.algorithm : canFind, filter, map;
import std.array : array;
import std.conv : to;
import std.format : format;
import std.string : strip, toLower;
import neko.eam.domain;
import neko.eam.application.dtos;
import neko.eam.application.usecases.searchelements : SearchElementsInteractor;
import neko.eam.application.usecases.transferelements : TransferElementsInteractor;
import neko.eam.ports.repositories;
import neko.eam.ports.services : IPasswordHasher;
import neko.eam.ports.usecases;

class AccessControlInteractor : IAccessControl {
	private {
		IEamUseCases _base;
		IElementRepository!User _users;
		IElementRepository!Role _roles;
		IElementRepository!Permission _permissions;
		IEamUseCases delegate() _sandbox;
		ICredentialRepository _credentials;
		IPasswordHasher _hasher;
		string _dummyHash; // verified for unknown users, so that they take as long as known ones
		// Resolution cache: every request resolves its caller, so users are indexed and rights are cached.
		// Both are dropped when users, roles or permissions change, or at midnight (validity dates).
		User[string] _byName, _byMail; // lower-case user name / e-mail -> first matching user
		Resolution[string] _resolved;
		string[string] _summaries; // role ids -> rights summary (users with the same roles share it)
		ulong _stamp = ulong.max;
		string _day;
	}
	enum maxCachedResolutions = 50_000;

	/// `sandbox` creates the throw-away copy used by dry-run imports (checked with the same rights).
	/// Without `credentials` / `hasher` the local sign-in is not available.
	this(IEamUseCases base, IElementRepository!User users, IElementRepository!Role roles,
			IElementRepository!Permission permissions, IEamUseCases delegate() sandbox,
			ICredentialRepository credentials = null, IPasswordHasher hasher = null) {
		_base = base; _users = users; _roles = roles; _permissions = permissions; _sandbox = sandbox;
		_credentials = credentials; _hasher = hasher;
	}

	AccessRightsDto rightsFor(AccessSubjectDto subject) {
		auto r = resolve(subject);
		AccessRightsDto dto;
		dto.userName = subject.userName;
		dto.displayName = subject.userName;
		dto.unrestricted = r.rights.unrestricted;
		dto.administrator = r.rights.isAdministrator;
		dto.source = r.source;
		dto.summary = r.rights.summary;
		if (r.user !is null) {
			dto.userId = r.user.id;
			dto.displayName = r.user.name;
			foreach (role; _roles.readAll)
				if (r.user.roleIds.canFind(role.id) && role.status == ObjectState.Active) dto.roles ~= role.name;
		}
		static foreach (S; EamDtoSets) {{
			auto s = r.rights.rightsOn(S.setName);
			dto.sets ~= SetRightsDto(S.setName, s.read, s.create, s.update, s.remove);
		}}
		return dto;
	}

	IEamUseCases useCasesFor(AccessSubjectDto subject) {
		auto r = resolve(subject).rights;
		if (r.unrestricted) return _base;
		return new SecuredEamFacade(_base, r, _sandbox);
	}

	bool isKnownUser(AccessSubjectDto subject) {
		auto u = lookupUser(subject);
		return u !is null && u.isEnabled(todayIso());
	}

	// ---------------------------------------------------------------- local sign-in

	SignInDto signIn(string userName, string password) {
		requireCredentials();
		auto user = lookupUser(AccessSubjectDto(userName.strip));
		auto credential = user is null ? null : _credentials.find(user.id);
		if (credential is null) {
			_hasher.verify(password, dummyHash); // same cost as a real check
			throw new InvalidCredentialsException;
		}
		if (!_hasher.verify(password, credential.passwordHash) || !user.isEnabled(todayIso()))
			throw new InvalidCredentialsException;
		if (_hasher.needsRehash(credential.passwordHash)) {
			credential.passwordHash = _hasher.hash(password);
			_credentials.save(credential);
		}
		return SignInDto(AccessSubjectDto(user.userName, user.email), user.id, user.name, credential.mustChange);
	}

	void setPassword(string userName, string newPassword, AccessSubjectDto by, bool mustChange = true) {
		requireCredentials();
		requireUserAdministration(by);
		auto user = requireUser(userName);
		PasswordPolicy.check(newPassword, user.userName);
		store(user, newPassword, by.userName, mustChange);
	}

	void changePassword(string userName, string currentPassword, string newPassword) {
		requireCredentials();
		auto user = lookupUser(AccessSubjectDto(userName));
		auto credential = user is null ? null : _credentials.find(user.id);
		if (credential is null || !_hasher.verify(currentPassword, credential.passwordHash))
			throw new ValidationException("currentPassword", "The current password is not correct");
		if (newPassword == currentPassword)
			throw new ValidationException("password", "The new password must differ from the current one");
		PasswordPolicy.check(newPassword, user.userName);
		store(user, newPassword, user.userName, false);
	}

	bool hasPassword(string userName) {
		if (_credentials is null) return false;
		auto user = lookupUser(AccessSubjectDto(userName));
		return user !is null && _credentials.find(user.id) !is null;
	}

	void removePassword(string userName, AccessSubjectDto by) {
		requireCredentials();
		requireUserAdministration(by);
		_credentials.remove(requireUser(userName).id);
	}

	/// Removes the password of a deleted user (called by the user use cases).
	void userRemoved(string userId) {
		if (_credentials !is null) _credentials.remove(userId);
	}

	private void store(User user, string password, string by, bool mustChange) {
		auto c = new Credential;
		c.userId = user.id;
		c.passwordHash = _hasher.hash(password);
		import std.datetime : Clock;
		c.changedAt = Clock.currTime().toUTC().toISOExtString();
		c.changedBy = by;
		c.mustChange = mustChange;
		_credentials.save(c);
	}

	private User requireUser(string userName) {
		auto user = lookupUser(AccessSubjectDto(userName));
		if (user is null || user.userName.toLower != userName.toLower) throw new EntityNotFoundException("Users", userName);
		return user;
	}

	private void requireUserAdministration(AccessSubjectDto by) {
		if (!resolve(by).rights.can("Users", AccessAction.Update))
			throw new AccessDeniedException("Users", "Setting passwords requires the permission to update Users");
	}

	private void requireCredentials() {
		if (_credentials is null || _hasher is null)
			throw new ValidationException("authMode", "Passwords are not available in this configuration");
	}

	private string dummyHash() {
		if (!_dummyHash.length) _dummyHash = _hasher.hash(randomDummy());
		return _dummyHash;
	}

	private static string randomDummy() {
		import std.random : uniform;
		char[24] buf;
		foreach (ref c; buf) c = cast(char) uniform!"[]"('!', '~');
		return buf.idup;
	}

	/// Summary of `rightsOfUser` (the derived field of every row of the user list - cached per role set).
	string rightsSummaryOf(User u) {
		import std.array : join;
		if (!u.isEnabled(todayIso())) return EffectiveRights.init.summary;
		refresh();
		auto key = u.roleIds.join("\n");
		if (auto s = key in _summaries) return *s;
		return _summaries[key] = rightsOfUser(u).summary;
	}

	/// Effective rights of a stored user (shown on the user's object page).
	EffectiveRights rightsOfUser(User u) {
		return EffectiveRights.resolve(u, _roles.readAll, _permissions.readAll, todayIso());
	}

	private struct Resolution { EffectiveRights rights; string source; User user; }

	/// Cached per subject; the result is shared and must not be modified.
	private Resolution resolve(AccessSubjectDto subject) {
		if (subject.administrator) return Resolution(EffectiveRights(true), "administrator");
		refresh();
		auto key = subject.userName.toLower ~ "\n" ~ subject.email.toLower;
		if (auto cached = key in _resolved) return *cached;
		if (_resolved.length >= maxCachedResolutions) _resolved = null;
		return _resolved[key] = resolveUncached(subject);
	}

	private Resolution resolveUncached(AccessSubjectDto subject) {
		auto user = lookupUser(subject);
		if (user is null) {
			if (_users.count == 0) {
				// fresh installation: everybody may look around until the first user is created
				EffectiveRights r;
				r.allSets.read = true;
				return Resolution(r, "bootstrap");
			}
			return Resolution(EffectiveRights.init, "unknown user");
		}
		if (!user.isEnabled(todayIso())) return Resolution(EffectiveRights.init, "disabled user", user);
		return Resolution(rightsOfUser(user), "user", user);
	}

	/// The user with the subject's user name, else with its e-mail (case-insensitive); null if none.
	/// The result is the shared snapshot entity - read only.
	private User lookupUser(AccessSubjectDto s) {
		refresh();
		auto name = s.userName.toLower, mail = s.email.toLower;
		if (name.length) if (auto u = name in _byName) return *u;
		if (mail.length) if (auto u = mail in _byMail) return *u;
		return null;
	}

	/// Rebuilds the user index and drops cached rights after a change of users, roles, permissions or the day.
	private void refresh() {
		auto stamp = _users.changeCount + _roles.changeCount + _permissions.changeCount;
		auto day = todayIso();
		if (stamp == _stamp && day == _day) return;
		User[string] byName, byMail;
		foreach (u; _users.readAll) {
			auto n = u.userName.toLower, m = u.email.toLower;
			if (n.length && n !in byName) byName[n] = u;
			if (m.length && m !in byMail) byMail[m] = u;
		}
		_byName = byName;
		_byMail = byMail;
		_resolved = null;
		_summaries = null;
		_stamp = stamp;
		_day = day;
	}
}

/// IManageElements decorator: checks the caller's rights before delegating.
class SecuredManageElements(TDto) : IManageElements!TDto {
	private {
		IManageElements!TDto _inner;
		EffectiveRights _rights;
		string _set;
	}

	this(IManageElements!TDto inner, EffectiveRights rights, string setName) {
		_inner = inner; _rights = rights; _set = setName;
	}

	string kind() { return _inner.kind; }
	TDto[] list() { require(AccessAction.Read); return _inner.list; }
	TDto get(string id) { require(AccessAction.Read); return _inner.get(id); }
	size_t count() { require(AccessAction.Read); return _inner.count; }
	TDto create(TDto dto, string actor = "system") { require(AccessAction.Create); return _inner.create(dto, actor); }
	TDto update(string id, TDto dto, string actor = "system") { require(AccessAction.Update); return _inner.update(id, dto, actor); }
	void remove(string id, string actor = "system") { require(AccessAction.Delete); _inner.remove(id, actor); }

	private void require(AccessAction action) {
		if (!_rights.can(_set, action))
			throw new AccessDeniedException(_set, format("No permission to %s %s", action.to!string.toLower, _set));
	}
}

/// IEamUseCases as seen by a caller with restricted rights.
class SecuredEamFacade : IEamUseCases {
	private {
		IEamUseCases _base;
		EffectiveRights _rights;
		IEamUseCases delegate() _sandbox;
	}

	this(IEamUseCases base, EffectiveRights rights, IEamUseCases delegate() sandbox) {
		_base = base; _rights = rights; _sandbox = sandbox;
	}

	static foreach (i, S; EamDtoSets)
		mixin("IManageElements!(EamDtoSets[" ~ i.to!string ~ "].Dto) " ~ S.accessor ~ "() {
			return new SecuredManageElements!(EamDtoSets[" ~ i.to!string ~ "].Dto)(manage!(EamDtoSets["
				~ i.to!string ~ "])(_base), _rights, \"" ~ S.setName ~ "\");
		}");

	/// Hits only from readable sets.
	ISearchElements search() { return new SearchElementsInteractor(this); }

	/// Export skips unreadable sets; import rows without create / update permission are reported as failed.
	ITransferElements transfer() {
		auto rights = _rights;
		auto sandbox = _sandbox;
		return new TransferElementsInteractor(this, () {
			IEamUseCases copy = sandbox();
			return cast(IEamUseCases) new SecuredEamFacade(copy, rights, sandbox);
		});
	}

	/// The analyses aggregate the application portfolio - they need read access to the applications.
	IAnalyzePortfolio analysis() {
		requireRead("Applications");
		return _base.analysis;
	}

	/// The ArchiMate model contains every architecture element - it needs read access to all of them.
	IArchiMateExport archimate() {
		static foreach (S; EamDtoSets)
			static if (!["Users", "Roles", "Permissions"].canFind(S.setName)) requireRead(S.setName);
		return _base.archimate;
	}

	/// Loading demo data is reserved for administrators.
	ISeedSampleData seeder() {
		throw new AccessDeniedException("", "Loading demo data requires administrator rights");
	}

	IAccessControl access() { return _base.access; }

	/// Notifications filter by the subject's rights themselves (every call names the subject).
	INotifications notifications() { return _base.notifications; }

	/// Comments: reading and writing needs read access to the element, deleting other users' comments
	/// the delete permission on the element's set.
	IComments comments() {
		import neko.eam.application.usecases.comments : CommentsInteractor;
		auto rights = _rights;
		return new CommentsInteractor(this, _base.comments, (string set) => rights.can(set, AccessAction.Delete));
	}

	/// Reports run against the checked use cases: report sets and referenced names need read access.
	IReporting reporting() {
		import neko.eam.application.usecases.reporting : ReportingInteractor;
		return new ReportingInteractor(this);
	}

	private void requireRead(string set) {
		if (!_rights.can(set, AccessAction.Read))
			throw new AccessDeniedException(set, "No permission to read " ~ set);
	}
}
