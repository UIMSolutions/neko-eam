/// Access control: resolves the effective rights of the caller from the users, roles and permissions of
/// the repository and hands out a checked view of the use cases (decorators around every driving port).
///
/// Resolution order:
///   1. administrator subject (XSUAA Admin scope, local operation without impersonation) -> unrestricted
///   2. repository user with the same user name or e-mail (case-insensitive) -> rights of its active roles
///   3. no users defined yet (fresh installation) -> read access to everything except access management
///   4. otherwise -> no rights
module neko.eam.application.usecases.accesscontrol;

import std.algorithm : canFind, filter, map;
import std.array : array;
import std.conv : to;
import std.format : format;
import std.string : toLower;
import neko.eam.domain;
import neko.eam.application.dtos;
import neko.eam.application.usecases.searchelements : SearchElementsInteractor;
import neko.eam.application.usecases.transferelements : TransferElementsInteractor;
import neko.eam.ports.repositories;
import neko.eam.ports.usecases;

class AccessControlInteractor : IAccessControl {
	private {
		IEamUseCases _base;
		IElementRepository!User _users;
		IElementRepository!Role _roles;
		IElementRepository!Permission _permissions;
		IEamUseCases delegate() _sandbox;
	}

	/// `sandbox` creates the throw-away copy used by dry-run imports (checked with the same rights).
	this(IEamUseCases base, IElementRepository!User users, IElementRepository!Role roles,
			IElementRepository!Permission permissions, IEamUseCases delegate() sandbox) {
		_base = base; _users = users; _roles = roles; _permissions = permissions; _sandbox = sandbox;
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
			foreach (role; _roles.findAll)
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
		auto u = findUser(_users.findAll, subject);
		return u !is null && u.isEnabled(todayIso());
	}

	/// Effective rights of a stored user (shown on the user's object page).
	EffectiveRights rightsOfUser(User u) {
		return EffectiveRights.resolve(u, _roles.findAll, _permissions.findAll, todayIso());
	}

	private struct Resolution { EffectiveRights rights; string source; User user; }

	private Resolution resolve(AccessSubjectDto subject) {
		if (subject.administrator) return Resolution(EffectiveRights(true), "administrator");
		auto users = _users.findAll;
		auto user = findUser(users, subject);
		if (user is null) {
			if (users.length == 0) {
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

	private static User findUser(User[] users, AccessSubjectDto s) {
		auto name = s.userName.toLower, mail = s.email.toLower;
		foreach (u; users) if (name.length && u.userName.toLower == name) return u;
		foreach (u; users) if (mail.length && u.email.length && u.email.toLower == mail) return u;
		return null;
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
	void remove(string id) { require(AccessAction.Delete); _inner.remove(id); }

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
