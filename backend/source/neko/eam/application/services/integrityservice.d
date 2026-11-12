/// Referential integrity across element kinds, driven by `@References` annotations.
module neko.eam.application.services.integrityservice;

import std.array : join;
import std.traits : hasUDA, getUDAs, FieldNameTuple;
import neko.eam.domain;
import neko.eam.ports.repositories;

class IntegrityService {
	private IRepositoryRegistry _registry;

	this(IRepositoryRegistry registry) {
		_registry = registry;
	}

	/// Every `@References` field of `entity` must point to an existing element.
	void checkReferences(T)(const T entity) {
		static foreach (name; FieldNameTuple!T) {
			static if (hasUDA!(__traits(getMember, T, name), References)) {
				{
					enum kind = getUDAs!(__traits(getMember, T, name), References)[0].kind;
					auto value = __traits(getMember, entity, name);
					static if (is(typeof(value) : const(string[]))) auto ids = value;
					else auto ids = value.length ? [value] : [];
					auto repo = _registry.byKind(kind);
					foreach (refId; ids) {
						if (refId == entity.id && kind == entityKindOf!T) continue; // self refs validated by entity
						if (repo is null || !repo.exists(refId))
							throw new ReferentialIntegrityException(
								"Field '" ~ name ~ "' references unknown " ~ kind ~ " '" ~ refId ~ "'");
					}
				}
			}
		}
	}

	/// Throws if any element still references `kind`/`id`.
	void checkNotReferenced(string kind, string id) {
		string[] usages;
		foreach (repo; _registry.all())
			foreach (refId; repo.findReferencing(kind, id))
				usages ~= repo.kind ~ "('" ~ refId ~ "')";
		if (usages.length)
			throw new ReferentialIntegrityException(
				kind ~ " '" ~ id ~ "' is still referenced by " ~ usages.join(", "));
	}
}

/// Entity set name of a domain entity type.
template entityKindOf(T) {
	static if (is(T == Application)) enum entityKindOf = "Applications";
	else static if (is(T == BusinessCapability)) enum entityKindOf = "BusinessCapabilities";
	else static if (is(T == ITComponent)) enum entityKindOf = "ITComponents";
	else static if (is(T == InformationFlow)) enum entityKindOf = "InformationFlows";
	else static if (is(T == Organization)) enum entityKindOf = "Organizations";
	else static if (is(T == Project)) enum entityKindOf = "Projects";
	else static if (is(T == Product)) enum entityKindOf = "Products";
	else static if (is(T == ProductGroup)) enum entityKindOf = "ProductGroups";
	else static if (is(T == ApplicationGroup)) enum entityKindOf = "ApplicationGroups";
	else static if (is(T == BusinessProcess)) enum entityKindOf = "BusinessProcesses";
	else static if (is(T == BusinessData)) enum entityKindOf = "BusinessData";
	else static if (is(T == ServiceProductGroup)) enum entityKindOf = "ServiceProductGroups";
	else static if (is(T == StrategicGuideline)) enum entityKindOf = "StrategicGuidelines";
	else static if (is(T == ServiceCapability)) enum entityKindOf = "ServiceCapabilities";
	else static if (is(T == MeasureGroup)) enum entityKindOf = "MeasureGroups";
	else static if (is(T == Measure)) enum entityKindOf = "Measures";
	else static if (is(T == ArchitecturePrinciple)) enum entityKindOf = "ArchitecturePrinciples";
	else static if (is(T == ArchitectureGuideline)) enum entityKindOf = "ArchitectureGuidelines";
	else static if (is(T == ReferenceArchitecture)) enum entityKindOf = "ReferenceArchitectures";
	else static if (is(T == ArchitectureDocument)) enum entityKindOf = "ArchitectureDocuments";
	else static if (is(T == SubProject)) enum entityKindOf = "SubProjects";
	else static if (is(T == WorkPackage)) enum entityKindOf = "WorkPackages";
	else static if (is(T == Enterprise)) enum entityKindOf = "Enterprises";
	else static if (is(T == Member)) enum entityKindOf = "Members";
	else static if (is(T == ITProcess)) enum entityKindOf = "ITProcesses";
	else static if (is(T == ProcessStep)) enum entityKindOf = "ProcessSteps";
	else static if (is(T == ProcessKpi)) enum entityKindOf = "ProcessKpis";
	else static if (is(T == ProtectionRequirement)) enum entityKindOf = "ProtectionRequirements";
	else static if (is(T == SecurityRisk)) enum entityKindOf = "SecurityRisks";
	else static if (is(T == SecurityControl)) enum entityKindOf = "SecurityControls";
	else static if (is(T == Report)) enum entityKindOf = "Reports";
	else static if (is(T == ReportBook)) enum entityKindOf = "ReportBooks";
	else static if (is(T == User)) enum entityKindOf = "Users";
	else static if (is(T == Role)) enum entityKindOf = "Roles";
	else static if (is(T == Permission)) enum entityKindOf = "Permissions";
	else static assert(0, "Unknown entity " ~ T.stringof);
}
