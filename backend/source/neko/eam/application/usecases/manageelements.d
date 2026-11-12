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
		void delegate(string) _onRemoved;
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

	/// Called after an element was deleted (e.g. to remove its comments).
	void onRemoved(void delegate(string id) callback) { _onRemoved = callback; }

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
		publish("Created", entity);
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
		publish("Updated", entity);
		return toDto(entity);
	}

	void remove(string id) {
		auto existing = require(id);
		_integrity.checkNotReferenced(kind, id);
		_repo.remove(id);
		if (_onRemoved !is null) _onRemoved(id);
		publish("Deleted", existing);
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

	private void publish(string type, TEntity e) {
		if (_events !is null) _events.publish(DomainEvent(type, kind, e.id, e.name, now()));
	}

	private static string now() {
		return Clock.currTime().toUTC().toISOExtString();
	}
}
