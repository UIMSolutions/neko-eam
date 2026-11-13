/// Generic CRUD interactor for all architecture element kinds.
module neko.eam.application.usecases.manageelements;

import std.datetime : Clock;
import std.uuid : randomUUID;
import std.string : strip;
import neko.eam.domain;
import neko.eam.application.dtos;
import neko.eam.application.services.integrityservice;
import neko.eam.ports.repositories;
import neko.eam.ports.usecases;
import neko.eam.ports.messaging;

class ManageElementsInteractor(TEntity, TDto) : IManageElements!TDto {
	private {
		IElementRepository!TEntity _repo;
		IntegrityService _integrity;
		IEventPublisher _events;
		void delegate(TEntity) _enricher;
		void delegate(TEntity) _validator;
		void delegate(string)[] _onRemoved;
	}

	this(IElementRepository!TEntity repo, IntegrityService integrity, IEventPublisher events) {
		_repo = repo;
		_integrity = integrity;
		_events = events;
	}

	string kind() { return entityKindOf!TEntity; }

	/// Registers a read-time enrichment (values computed from other aggregates, e.g. roll-ups).
	void enrichWith(void delegate(TEntity) enricher) { _enricher = enricher; }

	/// Registers an additional rule that needs other elements (e.g. uniqueness); runs after `validate()`.
	void validateWith(void delegate(TEntity) validator) { _validator = validator; }

	/// Called after an element was deleted (e.g. to remove its comments); callbacks run in registration order.
	void onRemoved(void delegate(string id) callback) { _onRemoved ~= callback; }

	TDto[] list() {
		TDto[] result;
		foreach (e; _repo.findAll) result ~= toDto(e);
		return result;
	}

	TDto get(string id) {
		return toDto(require(id));
	}

	size_t count() { return _repo.count; }

	TDto create(TDto dto, string actor = "system") {
		auto entity = mapFields!TEntity(dto);
		entity.id = entity.id.strip;
		if (entity.id.length == 0)
			entity.id = randomUUID().toString();
		if (_repo.exists(entity.id))
			throw new ConflictException(kind ~ " '" ~ entity.id ~ "' already exists");
		entity.createdAt = entity.modifiedAt = now();
		entity.createdBy = entity.modifiedBy = actor;
		derive(entity);
		entity.validate();
		if (_validator !is null) _validator(entity);
		_integrity.checkReferences(entity);
		_repo.save(entity);
		publish("Created", entity, actor);
		return toDto(entity);
	}

	TDto update(string id, TDto dto, string actor = "system") {
		auto existing = require(id);
		auto entity = mapFields!TEntity(dto);
		entity.id = existing.id;
		entity.createdAt = existing.createdAt;
		entity.createdBy = existing.createdBy;
		entity.modifiedAt = now();
		entity.modifiedBy = actor;
		derive(entity);
		entity.validate();
		if (_validator !is null) _validator(entity);
		_integrity.checkReferences(entity);
		_repo.save(entity);
		publish("Updated", entity, actor, existing, changedFields(existing, entity));
		return toDto(entity);
	}

	void remove(string id, string actor = "system") {
		auto existing = require(id);
		_integrity.checkNotReferenced(kind, id);
		_repo.remove(id);
		// published before the clean-up callbacks: listeners still see e.g. the element's comments
		publish("Deleted", existing, actor, existing);
		foreach (callback; _onRemoved) callback(id);
	}

	/// Entity-local derived values (e.g. reminder dates, product totals) before validation.
	private static void derive(TEntity e) {
		static if (__traits(hasMember, TEntity, "derive")) e.derive();
	}

	private TDto toDto(TEntity e) {
		if (_enricher !is null) _enricher(e);
		return mapFields!TDto(e);
	}

	private TEntity require(string id) {
		auto e = _repo.findById(id);
		if (e is null) throw new EntityNotFoundException(kind, id);
		return e;
	}

	/// `before`: the stored state before the change (creator and last editor are notified).
	private void publish(string type, TEntity e, string actor, TEntity before = null, string[] fields = null) {
		if (_events is null) return;
		auto ev = DomainEvent(type, kind, e.id, e.name, now(), actor);
		if (before !is null) { ev.createdBy = before.createdBy; ev.modifiedBy = before.modifiedBy; }
		ev.fields = fields;
		_events.publish(ev);
	}

	/// Maintained fields (not derived, not administrative) whose value differs.
	private static string[] changedFields(TEntity before, TEntity after) {
		import std.traits : FieldNameTuple, hasUDA;
		string[] r;
		auto a = mapFields!TDto(before), b = mapFields!TDto(after);
		static foreach (name; FieldNameTuple!TDto) {
			static if (!hasUDA!(__traits(getMember, TDto, name), ReadOnly) && name != "id")
				if (__traits(getMember, a, name) != __traits(getMember, b, name)) r ~= name;
		}
		return r;
	}

	private static string now() {
		return Clock.currTime().toUTC().toISOExtString();
	}
}
